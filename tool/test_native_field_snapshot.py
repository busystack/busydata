import types
import unittest
from unittest.mock import patch

import native_workbench_acceptance as native


class NativeFieldSnapshotTest(unittest.TestCase):
    def field(self, steps):
        state = dict(revision=1, owner=2, inflight=0)
        class Root:
            path = '/owned/root'
            def clear_cache(self): pass
            def get_parent(self): return None
            def get_process_id(self): return 17
            def get_attributes(self):
                return {'busydata-status':'ok','busydata-bridge-epoch':'1',
                    'busydata-owner-epoch':str(state['owner']),
                    'busydata-revision':str(state['revision']),
                    'busydata-action-sequence':'7',
                    'busydata-action-inflight':str(state['inflight'])}
        root = Root()
        class Field:
            def clear_cache(self): pass
            def get_parent(self): return root
            def get_state_set(self):
                return types.SimpleNamespace(contains=lambda flag: True)
        item = Field()
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1),
            CoordType=types.SimpleNamespace(WINDOW=1),
            Component=types.SimpleNamespace(get_extents=lambda *_:
                types.SimpleNamespace(x=10,y=20,width=200,height=35)),
            Text=types.SimpleNamespace(get_character_count=lambda _:4,
                get_caret_offset=lambda _:4))
        observed=[]
        def wait(predicate):
            for step in steps:
                state.update(step);observed.append(dict(state))
                value=predicate()
                if value:return value
            raise TimeoutError('Original native field deadline')
        return item, atspi, wait, observed

    def test_unchanged_geometry_does_not_acknowledge_a_changing_snapshot(self):
        item, atspi, wait, observations=self.field([{'revision':1},{'revision':2},
            {'revision':3},{'revision':3}])
        with patch.object(native,'focus_live_native_control',return_value=item):
            self.assertIs(item,native.focus_visible_native_field(atspi,lambda:item,wait))
        self.assertEqual(4,len(observations))

    def test_queued_native_action_must_finish_before_field_readiness(self):
        item,atspi,wait,observations=self.field([{'inflight':1},{'inflight':1},
            {'inflight':0},{'inflight':0}])
        with patch.object(native,'focus_live_native_control',return_value=item):
            self.assertIs(item,native.focus_visible_native_field(atspi,lambda:item,wait))
        self.assertEqual(4,len(observations))

    def test_owner_change_cannot_be_accepted_as_a_settled_field(self):
        item,atspi,wait,_=self.field([{'owner':2},{'owner':3},{'owner':3}])
        with patch.object(native,'focus_live_native_control',return_value=item):
            with self.assertRaisesRegex(RuntimeError,'snapshot owner changed'):
                native.focus_visible_native_field(atspi,lambda:item,wait)

    def test_malformed_snapshot_receipt_never_certifies_field_readiness(self):
        item,atspi,wait,_=self.field([{'revision':'invalid'},{'revision':'invalid'}])
        with patch.object(native,'focus_live_native_control',return_value=item):
            with self.assertRaisesRegex(RuntimeError,'snapshot receipt'):
                native.focus_visible_native_field(atspi,lambda:item,wait)


if __name__=='__main__': unittest.main()
