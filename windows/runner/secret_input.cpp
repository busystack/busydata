// Windows secret entry uses an app-owned protected EDIT and unmodified SDKs.
#include <initguid.h>
#include "secret_input.h"
#include <flutter/standard_method_codec.h>
#include <oleacc.h>
#include <algorithm>
#include <stdexcept>
#include <vector>
#pragma comment(lib, "oleacc.lib")
#pragma comment(lib, "uuid.lib")
namespace {
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
const V& Get(const M& map, const char* name) {
  const auto entry = map.find(V(name));
  if (entry == map.end()) throw std::invalid_argument("Missing editing member");
  return entry->second;
}
int64_t Integer(const M& map, const char* name) {
  const auto& value = Get(map, name);
  if (const auto* integer = std::get_if<int32_t>(&value)) return *integer;
  if (const auto* integer = std::get_if<int64_t>(&value)) return *integer;
  throw std::invalid_argument("Invalid editing integer");
}
bool Boolean(const M& map, const char* name) { return std::get<bool>(Get(map, name)); }
std::wstring Utf16(const M& map, const char* name) {
  const auto& units = std::get<std::vector<int32_t>>(Get(map, name));
  std::wstring text;
  text.reserve(units.size());
  for (const auto unit : units) {
    if (unit < 0 || unit > 0xffff) throw std::invalid_argument("Invalid editing unit");
    text.push_back(static_cast<wchar_t>(unit));
  }
  return text;
}
std::wstring Read(HWND edit) {
  const int length = GetWindowTextLengthW(edit);
  std::wstring text(static_cast<size_t>(length) + 1, L'\0');
  const int copied = GetWindowTextW(edit, text.data(), length + 1);
  text.resize(static_cast<size_t>(copied));
  return text;
}
void Wipe(std::wstring& text) {
  if (!text.empty()) SecureZeroMemory(text.data(), text.size() * sizeof(wchar_t));
}
}  // namespace
struct WindowsSecretInput::Field {
  WindowsSecretInput* owner = nullptr;
  int64_t id = 0, generation = -1, serial = 0;
  HWND edit = nullptr;
  WNDPROC previous = nullptr;
  IAccPropServices* properties = nullptr;
  std::wstring label;
  std::wstring hint;
  HFONT font = nullptr;
  int font_height = 0;
  std::wstring font_family;
  bool rtl = false;
  HBRUSH brush = nullptr;
  COLORREF background = RGB(255,255,255), foreground = RGB(0,0,0);
  bool setting = false, accepts_input = true, pending_tab = false, backwards = false;
  ~Field() {
    setting = true;
    if (edit) {
      if (properties) {
        const MSAAPROPID keys[] = {PROPID_ACC_NAME, PROPID_ACC_DESCRIPTION};
        properties->ClearHwndProps(edit, static_cast<DWORD>(OBJID_CLIENT), CHILDID_SELF, keys, 2);
      }
      SetWindowTextW(edit, L"");
      if (previous) SetWindowLongPtrW(edit, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(previous));
      SetWindowLongPtrW(edit, GWLP_USERDATA, 0);
      DestroyWindow(edit);
    }
    if (properties) properties->Release();
    if (font) DeleteObject(font);
    if (brush) DeleteObject(brush);
  }
};
WindowsSecretInput::WindowsSecretInput(HWND root, HWND view, flutter::BinaryMessenger* messenger)
    : root_(root), view_(view) {
  SetWindowLongPtrW(root_, GWL_STYLE, GetWindowLongPtrW(root_, GWL_STYLE) | WS_CLIPCHILDREN);
  SetWindowLongPtrW(view_, GWL_STYLE, GetWindowLongPtrW(view_, GWL_STYLE) | WS_CLIPSIBLINGS);
  for (const auto window : {root_, view_}) {
    SetWindowPos(window, nullptr, 0,0,0,0, SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
  }
  channel_ = std::make_unique<flutter::MethodChannel<V>>(messenger,
      "org.busystack.busydata/windows_secret_input", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    int64_t request_id = 0;
    bool configuring = false;
    try {
      const auto* decoded = call.arguments() ? std::get_if<M>(call.arguments()) : nullptr;
      if (!decoded) {result->Error("invalid_input", "Expected an editing owner map");return;}
      const auto& arguments = *decoded;
      const auto& owner = std::get<std::string>(Get(arguments, "owner"));
      if (owner.size() != 32 || owner.find_first_not_of("0123456789abcdef") != std::string::npos)
        throw std::invalid_argument("Invalid editing owner");
      if (call.method_name() == "initialize") {
        if (owner_ != owner) {
          while (!fields_.empty()) Destroy(fields_.begin()->first);
          owner_ = owner;
        }
        result->Success(); return;
      }
      if (owner != owner_) { result->Error("stale_owner", "Editing owner changed"); return; }
      const int64_t id = Integer(arguments, "id");
      if (id <= 0) throw std::invalid_argument("Invalid field identity");
      if (call.method_name() == "dispose") { Destroy(id); result->Success(); return; }
      auto found = fields_.find(id);
      if (call.method_name() == "configure") {
        request_id = id; configuring = true;
        const int64_t generation = Integer(arguments,"generation");
        const auto logical_x=Integer(arguments,"x"), logical_y=Integer(arguments,"y");
        const auto logical_width=Integer(arguments,"width"), logical_height=Integer(arguments,"height");
        if (generation<0 || logical_x < -1000000 || logical_x > 1000000 ||
            logical_y < -1000000 || logical_y > 1000000 ||
            logical_width<1 || logical_width>32767 || logical_height<1 || logical_height>32767)
          throw std::invalid_argument("Invalid editing geometry");
        const int x=static_cast<int>(logical_x), y=static_cast<int>(logical_y);
        const int width=static_cast<int>(logical_width), height=static_cast<int>(logical_height);
        const bool enabled=Boolean(arguments,"enabled"), read_only=Boolean(arguments,"readOnly");
        const bool visible=Boolean(arguments,"visible"), accepts_input=Boolean(arguments,"acceptsInput");
        const int font_height = static_cast<int>(Integer(arguments,"fontHeight"));
        if (font_height < 1 || font_height > 4096) throw std::invalid_argument("Invalid font height");
        const auto font_family = Utf16(arguments,"fontFamily");
        if (font_family.size() >= LF_FACESIZE || font_family.find(L'\0') != std::wstring::npos)
          throw std::invalid_argument("Invalid font family");
        const bool rtl = Boolean(arguments,"rtl");
        const auto color = [&](const char* key) {
          const auto value = static_cast<uint32_t>(Integer(arguments,key));
          return RGB((value >> 16) & 255,(value >> 8) & 255,value & 255);
        };
        const COLORREF requested_background = color("background"), requested_foreground = color("foreground");
        const auto label=Utf16(arguments,"label");
        const auto hint=Utf16(arguments,"hint");
        if(std::find(label.begin(),label.end(),0)!=label.end())throw std::invalid_argument("Invalid native label");
        if(hint.find(L'\0')!=std::wstring::npos)throw std::invalid_argument("Invalid native description");
        const auto payload = arguments.find(V("utf16"));
        const bool has_value = payload != arguments.end();
        const auto* encoded = has_value ? std::get_if<std::vector<int32_t>>(&payload->second) : nullptr;
        if (has_value && !encoded) throw std::invalid_argument("Invalid editing payload");
        // Reject before touching the native value. The backing Dart controller
        // remains unchanged; an unsupported input must never silently truncate.
        if (encoded && std::find(encoded->begin(),encoded->end(),0) != encoded->end()) {
          Destroy(id); result->Error("unrepresentable_input", "Native input cannot represent the supplied state"); return;
        }
        if (found == fields_.end()) {
          if (!has_value) throw std::invalid_argument("Initial editing state required");
          auto field = std::make_unique<Field>(); field->id=id; field->owner=this;
          field->edit=CreateWindowExW(0,L"EDIT",L"",
              WS_CHILD|WS_VISIBLE|WS_CLIPSIBLINGS|WS_TABSTOP|ES_PASSWORD|ES_AUTOHSCROLL,
              0,0,1,1,root_,reinterpret_cast<HMENU>(static_cast<INT_PTR>(4096+id)),GetModuleHandle(nullptr),nullptr);
          if (!field->edit) throw std::runtime_error("Native edit creation failed");
          if (FAILED(CoCreateInstance(CLSID_AccPropServices,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&field->properties))))
            throw std::runtime_error("Native name service unavailable");
          if (FAILED(field->properties->SetHwndPropStr(field->edit,static_cast<DWORD>(OBJID_CLIENT),CHILDID_SELF,PROPID_ACC_NAME,label.c_str())))
            throw std::runtime_error("Native field label unavailable");
          field->label=label;
          SetWindowLongPtrW(field->edit,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(field.get()));
          field->previous=reinterpret_cast<WNDPROC>(SetWindowLongPtrW(field->edit,GWLP_WNDPROC,reinterpret_cast<LONG_PTR>(EditProcedure)));
          SendMessageW(field->edit,EM_SETLIMITTEXT,0,0);
          found=fields_.emplace(id,std::move(field)).first;
        }
        auto& field=*found->second;
        if (generation < field.generation) { result->Error("stale_input", "Editing owner changed"); return; }
        if(field.label!=label){
          if(FAILED(field.properties->SetHwndPropStr(field.edit,static_cast<DWORD>(OBJID_CLIENT),CHILDID_SELF,PROPID_ACC_NAME,label.c_str())))
            throw std::runtime_error("Native field label update unavailable");
          field.label=label;
        }
        if(field.hint!=hint){
          if(FAILED(field.properties->SetHwndPropStr(field.edit,static_cast<DWORD>(OBJID_CLIENT),CHILDID_SELF,PROPID_ACC_DESCRIPTION,hint.c_str())))
            throw std::runtime_error("Native field description unavailable");
          field.hint=hint;
        }
        if (generation > field.generation) {
          if (!has_value) throw std::invalid_argument("New editing state required");
          auto value=Utf16(arguments,"utf16");
          const auto base=Integer(arguments,"base"), extent=Integer(arguments,"extent");
          if(base < -1 || extent < -1 || base > static_cast<int64_t>(value.size()) || extent > static_cast<int64_t>(value.size()) || ((base<0)!=(extent<0))) {
            Wipe(value); throw std::invalid_argument("Invalid editing selection");
          }
          field.setting=true; SetWindowTextW(field.edit,value.c_str());
          auto actual=Read(field.edit); const bool exact=actual==value; Wipe(actual); Wipe(value);
          if(!exact) {field.setting=false; Destroy(id);result->Error("unrepresentable_input","Native editing round trip differed");return;}
          SendMessageW(field.edit,EM_SETSEL,static_cast<WPARAM>(base),static_cast<LPARAM>(extent));
          field.generation=generation;field.serial=0;field.setting=false;
        }
        field.accepts_input=accepts_input;
        HIGHCONTRASTW contrast{sizeof(contrast)};
        const bool high_contrast = SystemParametersInfoW(SPI_GETHIGHCONTRAST,sizeof(contrast),&contrast,0) &&
            (contrast.dwFlags & HCF_HIGHCONTRASTON);
        const auto background = high_contrast ? GetSysColor(COLOR_WINDOW) : requested_background;
        if (!field.brush || field.background != background) {
          if (field.brush) DeleteObject(field.brush);
          field.background = background; field.brush = CreateSolidBrush(background);
          if (!field.brush) throw std::runtime_error("Native brush unavailable");
        }
        field.foreground = high_contrast ? GetSysColor(enabled ? COLOR_WINDOWTEXT : COLOR_GRAYTEXT) : requested_foreground;
        if (!field.font || field.font_height != font_height || field.font_family != font_family) {
          auto font = CreateFontW(-font_height,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,
              DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,
              DEFAULT_PITCH,font_family.c_str());
          if (!font) throw std::runtime_error("Native font unavailable");
          SendMessageW(field.edit,WM_SETFONT,reinterpret_cast<WPARAM>(font),TRUE);
          if (field.font) DeleteObject(field.font);
          field.font=font; field.font_height=font_height; field.font_family=font_family;
        }
        if (field.rtl != rtl) {
          auto style = GetWindowLongPtrW(field.edit,GWL_STYLE);
          SetWindowLongPtrW(field.edit,GWL_STYLE,rtl ? style | ES_RIGHT : style & ~ES_RIGHT);
          auto ex_style = GetWindowLongPtrW(field.edit,GWL_EXSTYLE);
          SetWindowLongPtrW(field.edit,GWL_EXSTYLE,rtl ? ex_style | WS_EX_RTLREADING : ex_style & ~WS_EX_RTLREADING);
          field.rtl=rtl;
        }
        // The HWND remains above the Flutter surface only inside the painted
        // field and outside actual Flutter overlays. Windows owns the region.
        const auto& clips=std::get<std::vector<int32_t>>(Get(arguments,"clip"));
        const auto& exclusions=std::get<std::vector<int32_t>>(Get(arguments,"exclusions"));
        if (clips.size()!=4 || exclusions.size()%4!=0) throw std::invalid_argument("Invalid field clip");
        HRGN region=CreateRectRgn(clips[0],clips[1],clips[2],clips[3]);
        if (!region) throw std::runtime_error("Native clip unavailable");
        for (size_t i=0;i<exclusions.size();i+=4) {
          HRGN cut=CreateRectRgn(exclusions[i],exclusions[i+1],exclusions[i+2],exclusions[i+3]);
          if (!cut || CombineRgn(region,region,cut,RGN_DIFF)==ERROR) {
            if (cut) DeleteObject(cut); DeleteObject(region);
            throw std::runtime_error("Native overlay clip unavailable");
          }
          DeleteObject(cut);
        }
        if (!SetWindowRgn(field.edit,region,TRUE)) {
          DeleteObject(region); throw std::runtime_error("Native clip update unavailable");
        }
        EnableWindow(field.edit,enabled);
        SendMessageW(field.edit,EM_SETREADONLY,read_only,0);
        SetWindowPos(field.edit,HWND_TOP,x,y,width,height,SWP_NOACTIVATE);
        ShowWindow(field.edit,visible?SW_SHOWNOACTIVATE:SW_HIDE);
        InvalidateRect(field.edit,nullptr,TRUE);
        result->Success();return;
      }
      if(found==fields_.end()){result->Error("disposed_input","Editing owner no longer exists");return;}
      auto& field=*found->second;
      if(call.method_name()=="focus"){
        if(Integer(arguments,"generation")!=field.generation){result->Error("stale_input","Editing focus owner changed");return;}
        if(IsWindowVisible(field.edit)&&IsWindowEnabled(field.edit))SetFocus(field.edit);
        result->Success();return;
      }
      if(call.method_name()=="flush"){
        if(Integer(arguments,"generation")!=field.generation){result->Error("stale_input","Editing owner changed");return;}
        Emit(field);result->Success();return;
      }
      result->NotImplemented();
    } catch (const std::exception&) {
      if (configuring) Destroy(request_id);
      result->Error("invalid_input","Invalid native editing request");
    }
  });
}
WindowsSecretInput::~WindowsSecretInput(){
  channel_->SetMethodCallHandler(nullptr);
  while(!fields_.empty())Destroy(fields_.begin()->first);
}
void WindowsSecretInput::Destroy(int64_t id){
  // DestroyWindow can send synchronous parent notifications. Unlink the owner
  // before its HWND/resources are destroyed so those messages cannot observe
  // a map entry that is being torn down.
  auto removed=fields_.extract(id);
  (void)removed;
}
void WindowsSecretInput::Emit(Field& field) {
  if(field.setting||!field.accepts_input)return;
  auto text=Read(field.edit);std::vector<int32_t> units;units.reserve(text.size());
  for(const auto unit:text)units.push_back(static_cast<int32_t>(unit));
  Wipe(text);DWORD first=0,last=0;SendMessageW(field.edit,EM_GETSEL,reinterpret_cast<WPARAM>(&first),reinterpret_cast<LPARAM>(&last));
  M state;state[V("owner")]=V(owner_);state[V("id")]=V(field.id);state[V("generation")]=V(field.generation);state[V("serial")]=V(++field.serial);
  state[V("utf16")]=V(std::move(units));state[V("base")]=V(static_cast<int64_t>(first));state[V("extent")]=V(static_cast<int64_t>(last));
  channel_->InvokeMethod("editing",std::make_unique<V>(state));
}
LRESULT CALLBACK WindowsSecretInput::EditProcedure(HWND window,UINT message,WPARAM wparam,LPARAM lparam){
  auto* field=reinterpret_cast<Field*>(GetWindowLongPtrW(window,GWLP_USERDATA));
  if(!field||!field->previous)return DefWindowProcW(window,message,wparam,lparam);
  if(message==WM_KEYDOWN&&wparam==VK_TAB){field->pending_tab=true;field->backwards=(GetKeyState(VK_SHIFT)&0x8000)!=0;return 0;}
  if(message==WM_KEYUP&&wparam==VK_TAB&&field->pending_tab){
    field->pending_tab=false;SetFocus(field->owner->view_);M event;event[V("owner")]=V(field->owner->owner_);event[V("id")]=V(field->id);event[V("generation")]=V(field->generation);event[V("backwards")]=V(field->backwards);
    field->owner->channel_->InvokeMethod("traverse",std::make_unique<V>(event));return 0;
  }
  if(message==WM_CHAR&&(wparam==VK_TAB||wparam==VK_RETURN||wparam==VK_ESCAPE||wparam==1))return 0;
  if(message==WM_KEYDOWN&&wparam=='A'&&(GetKeyState(VK_CONTROL)&0x8000)!=0){SendMessageW(window,EM_SETSEL,0,-1);field->owner->Emit(*field);return 0;}
  const auto result=CallWindowProcW(field->previous,window,message,wparam,lparam);
  if(message==WM_LBUTTONUP||message==WM_KEYUP)field->owner->Emit(*field);
  return result;
}
bool WindowsSecretInput::HandleMessage(UINT message,WPARAM wparam,LPARAM lparam,LRESULT* result){
  for(auto& item:fields_){auto& field=*item.second;if(reinterpret_cast<HWND>(lparam)!=field.edit)continue;
    if((message==WM_CTLCOLOREDIT||message==WM_CTLCOLORSTATIC)&&field.brush){auto dc=reinterpret_cast<HDC>(wparam);SetTextColor(dc,field.foreground);SetBkColor(dc,field.background);*result=reinterpret_cast<LRESULT>(field.brush);return true;}
    if(message==WM_COMMAND){
      const auto code=HIWORD(wparam);
      if(code==EN_CHANGE||code==EN_KILLFOCUS)Emit(field);
      if(code==EN_SETFOCUS||code==EN_KILLFOCUS){
        M event;event[V("owner")]=V(owner_);event[V("id")]=V(field.id);event[V("generation")]=V(field.generation);
        event[V("focused")]=V(code==EN_SETFOCUS);
        channel_->InvokeMethod("focusChanged",std::make_unique<V>(event));
      }
      *result=0;return true;
    }
  }
  return false;
}
