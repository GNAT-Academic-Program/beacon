# Test coverage

## Registration task safety

`registration_tests` checks concurrent startup registration of distinct subscribers.
The workers share a start barrier and join before their subscriber storage leaves scope.

- Three workers fit within three slots and receive one publication each.
- Three workers competing for two slots produce two successes and one rejection.
- Duplicate registration leaves the subscriber count unchanged.
- A second publisher is rejected.
- Publish closes registration.
- Try_Publish closes registration even with no subscribers.
- Late registration leaves membership and the count unchanged.

These tests do not prove all task schedules or subscriber lifetime safety.
Calls on the same publisher must remain serialized.
