"""Check the ordinary release's finite Yaru catalog in its actual font subset.

Widget tests load full package fonts. They cannot detect release-only missing
glyphs. This bounded SFNT cmap reader needs no new dependency or SDK patch.
"""
import hashlib
import json
from pathlib import Path
import re
import struct
from urllib.parse import urljoin, urlparse

ROOT = Path(__file__).resolve().parents[1]


def glyph_index(data, codepoint):
    if not 12 <= len(data) <= 4 * 1024 * 1024:
        raise ValueError('Icon font byte budget')
    def read(fmt, offset, end=None):
        size = struct.calcsize(fmt)
        if offset < 0 or offset + size > (len(data) if end is None else end):
            raise ValueError('Truncated icon font cmap')
        return struct.unpack_from(fmt, data, offset)
    tables = read('>H', 4)[0]
    if not 1 <= tables <= 128:
        raise ValueError('Icon font table budget')
    cmap = None
    for index in range(tables):
        tag, _, offset, length = read('>4sIII', 12 + index * 16)
        if offset + length > len(data):
            raise ValueError('Truncated icon font table')
        if tag == b'cmap':
            cmap = offset, offset + length
    if cmap is None:
        raise ValueError('Icon font has no cmap')
    start, end = cmap
    count = read('>H', start + 2, end)[0]
    if not 1 <= count <= 64:
        raise ValueError('Icon font cmap budget')
    for index in range(count):
        platform, encoding, relative = read('>HHI', start + 4 + index * 8, end)
        if platform != 0 and (platform != 3 or encoding not in (1, 10)):
            continue
        sub = start + relative
        form = read('>H', sub, end)[0]
        if form == 4 and codepoint <= 0xffff:
            length = read('>H', sub + 2, end)[0]
            sub_end = sub + length
            if sub_end > end:
                raise ValueError('Truncated format-4 cmap')
            segments = read('>H', sub + 6, sub_end)[0] // 2
            if not 1 <= segments <= 32768:
                raise ValueError('Icon font segment budget')
            ends = sub + 14
            starts = ends + segments * 2 + 2
            deltas = starts + segments * 2
            ranges = deltas + segments * 2
            for segment in range(segments):
                last = read('>H', ends + segment * 2, sub_end)[0]
                first = read('>H', starts + segment * 2, sub_end)[0]
                if not first <= codepoint <= last:
                    continue
                delta = read('>h', deltas + segment * 2, sub_end)[0]
                distance = read('>H', ranges + segment * 2, sub_end)[0]
                if distance == 0:
                    glyph = (codepoint + delta) & 0xffff
                else:
                    glyph = read('>H', ranges + segment * 2 + distance + (codepoint - first) * 2, sub_end)[0]
                    if glyph:
                        glyph = (glyph + delta) & 0xffff
                if glyph:
                    return glyph
        elif form == 12:
            length = read('>I', sub + 4, end)[0]
            sub_end = sub + length
            if sub_end > end:
                raise ValueError('Truncated format-12 cmap')
            groups = read('>I', sub + 12, sub_end)[0]
            if groups > 65536:
                raise ValueError('Icon font group budget')
            for group in range(groups):
                first, last, glyph = read('>III', sub + 16 + group * 12, sub_end)
                if first <= codepoint <= last and glyph + codepoint - first:
                    return glyph + codepoint - first
    return 0


def verify_linux_icon_font(bundle, root=ROOT):
    catalog_path = root / 'lib/src/ui/linux/linux_controls.dart'
    catalog = catalog_path.read_text().split('const _linuxGlyphs = ', 1)[1].split('};', 1)[0]
    names = sorted(set(re.findall(r'YaruIcons\.(\w+)', catalog)))
    if not 1 <= len(names) <= 64:
        raise ValueError('Finite Linux icon catalog required')
    config_path = root / '.dart_tool/package_config.json'
    package = next(item for item in json.loads(config_path.read_text())['packages'] if item['name'] == 'yaru')
    package_root = Path(urlparse(urljoin(config_path.as_uri(), package['rootUri'])).path)
    definitions = (package_root / 'lib/src/icons/yaru_icons.dart').read_text()
    font_path = bundle / 'data/flutter_assets/packages/yaru/assets/yaru_icons.otf'
    data = font_path.read_bytes()
    glyphs = {}
    for name in names:
        match = re.search(r'static const ' + re.escape(name) + r' = IconData\(\s*(0x[0-9a-fA-F]+)', definitions)
        if match is None:
            raise ValueError('Missing pinned Yaru glyph: ' + name)
        codepoint = int(match.group(1), 16)
        glyph = glyph_index(data, codepoint)
        if glyph == 0:
            raise ValueError('Release icon font omits Yaru glyph: ' + name)
        glyphs[name] = {'codePoint': codepoint, 'glyphIndex': glyph}
    return {'passed': True, 'asset': str(font_path.relative_to(bundle)),
            'sha256': hashlib.sha256(data).hexdigest(), 'glyphs': glyphs}
