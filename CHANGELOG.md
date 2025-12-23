### What's changed in v0.10.0

* feat: import subnet pool - used in e2e test (#17) (by @patrickleet)

  * **New Features**
    * Subnet pools now support external name references to adopt existing external pools.
    * Management policies added for subnet pools to control lifecycle operations (Create, Observe, Update, Delete, LateInitialize).

  * **Tests**
    * End-to-end test scenarios updated to exercise persistent IPv4/IPv6 subnet pool configurations.


See full diff: [v0.9.0...v0.10.0](https://github.com/hops-ops/configuration-aws-ipam/compare/v0.9.0...v0.10.0)
