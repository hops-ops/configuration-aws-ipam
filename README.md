# configuration-aws-ipam

Centralized IP address management for AWS. Stop tracking CIDRs in spreadsheets - request them from pools and let IPAM handle allocation, overlap prevention, and auditing.

## Why IPAM?

**Without IPAM:**
- Manual CIDR tracking in spreadsheets or wikis
- Overlapping ranges when teams don't coordinate
- No audit trail of who allocated what
- IPv6 adoption feels impossible

**With IPAM:**
- Automatic CIDR allocation from pools
- Guaranteed non-overlapping ranges
- Full audit trail in AWS
- Dual-stack (IPv4 + IPv6) ready for modern workloads
- Share pools across accounts via RAM

## The Journey

### Stage 1: Single Account IPAM

You have one AWS account and want organized IP allocation for your VPCs.

**Why start with IPAM early?**
- When you add accounts later, VPCs won't overlap
- Dual-stack (IPv6) ready from day one
- No migration pain - just keep using the same pools

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPAM
metadata:
  name: my-ipam
  namespace: default
spec:
  providerConfigRef:
    name: default
  region: us-east-1
  operatingRegions:
    - us-east-1
  pools:
    ipv4:
      # IPv4 for VPCs - 10.0.0.0/8 gives you 16 million addresses
      - name: ipv4
        region: us-east-1
        cidr: 10.0.0.0/8
        allocations:
          netmaskLength:
            default: 20  # /20 = 4096 IPs per VPC
            min: 16
            max: 24
        description: IPv4 pool for VPCs
```

### Stage 2: Add IPv6 for Modern Workloads

IPv6 eliminates IP exhaustion concerns and enables modern networking patterns.

**Why IPv6?**
- Pods get native IPv6 addresses (no NAT overhead)
- Essentially unlimited IPs - /80 prefix = 281 trillion addresses per node
- Future-proof your infrastructure

**Two types of IPv6 pools:**
- **Public (GUA)** - Internet-routable Amazon-provided addresses for public-facing workloads
- **Private (ULA)** - Internal-only from fd00::/8, for service mesh and databases

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPAM
metadata:
  name: my-ipam
  namespace: default
spec:
  providerConfigRef:
    name: default
  region: us-east-1
  operatingRegions:
    - us-east-1
  pools:
    ipv4:
      - name: ipv4
        region: us-east-1
        cidr: 10.0.0.0/8
        allocations:
          netmaskLength:
            default: 20

    ipv6:
      # IPv6 private - AWS auto-assigns from fd00::/8 ULA range
      ula:
        - name: ipv6-private
          region: us-east-1
          locale: us-east-1
          netmaskLength: 48  # AWS auto-assigns ULA CIDR
          allocations:
            netmaskLength:
              default: 56
              min: 48
              max: 64
          description: Private IPv6 for internal services

      # IPv6 public - Amazon provides /52, you allocate /56 per VPC
      gua:
        - name: ipv6-public
          region: us-east-1
          locale: us-east-1
          netmaskLength: 52  # AWS provisions /52 block
          allocations:
            netmaskLength:
              default: 56  # /56 per VPC
              min: 52
              max: 60
          description: Public IPv6 for internet-facing workloads
```

### Stage 3: Multi-Region

Expanding to multiple regions? Add them to operatingRegions and create regional child pools.

**Why regional pools?**
- Lower latency for regional workloads
- Compliance requirements (data residency)
- Disaster recovery across regions

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPAM
metadata:
  name: my-ipam
  namespace: default
spec:
  providerConfigRef:
    name: default
  region: us-east-1
  operatingRegions:
    - us-east-1
    - us-west-2
    - eu-west-1
  pools:
    ipv4:
      # Global pool - top of hierarchy
      - name: ipv4-global
        region: us-east-1
        cidr: 10.0.0.0/8
        allocations:
          netmaskLength:
            default: 12

      # US East regional pool (child of global)
      - name: ipv4-us-east-1
        sourcePoolRef: ipv4-global
        region: us-east-1
        locale: us-east-1
        cidr: 10.0.0.0/12    # 10.0.0.0 - 10.15.255.255
        allocations:
          netmaskLength:
            default: 20

      # US West regional pool (child of global)
      - name: ipv4-us-west-2
        sourcePoolRef: ipv4-global
        region: us-west-2
        locale: us-west-2
        cidr: 10.16.0.0/12   # 10.16.0.0 - 10.31.255.255
        allocations:
          netmaskLength:
            default: 20

      # EU regional pool (child of global)
      - name: ipv4-eu-west-1
        sourcePoolRef: ipv4-global
        region: eu-west-1
        locale: eu-west-1
        cidr: 10.32.0.0/12   # 10.32.0.0 - 10.47.255.255
        allocations:
          netmaskLength:
            default: 20
```

### Stage 4: Import Existing IPAM

Already have an IPAM? Import it along with existing pools.

**Why import?**
- Preserve existing allocations
- No disruption to running VPCs
- Gradually bring under Crossplane management

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPAM
metadata:
  name: existing-ipam
  namespace: default
spec:
  # Import existing IPAM
  externalName: ipam-0123456789abcdef0
  managementPolicies: ["Observe", "Update", "LateInitialize"]

  providerConfigRef:
    name: default
  region: us-east-1
  operatingRegions:
    - us-east-1
  pools:
    ipv4:
      - name: ipv4
        region: us-east-1
        cidr: 10.0.0.0/8
        # Import existing pool and its CIDR allocation
        externalName: ipam-pool-0123456789abcdef0
        cidrExternalName: 10.0.0.0/8_ipam-pool-0123456789abcdef0
        managementPolicies: ["Observe", "Update", "LateInitialize"]
        allocations:
          netmaskLength:
            default: 20
```

## Using IPAM Pools

Reference pool IDs from status when creating VPCs:

```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: VPC
spec:
  forProvider:
    region: us-east-1
    # IPv4 from IPAM
    ipv4IpamPoolId: ipam-pool-abc123  # From status.pools.ipv4[name=ipv4].id
    ipv4NetmaskLength: 20
    # IPv6 from IPAM (for dual-stack)
    ipv6IpamPoolId: ipam-pool-xyz789  # From status.pools.ipv6.gua[name=ipv6-public].id
    ipv6NetmaskLength: 56
```

## Status

IPAM exposes pool IDs and CIDRs for downstream resources:

```yaml
status:
  id: ipam-0123456789abcdef0
  arn: arn:aws:ec2:us-east-1:111111111111:ipam/ipam-0123456789abcdef0
  privateDefaultScopeId: ipam-scope-abc123
  publicDefaultScopeId: ipam-scope-xyz789
  pools:
    ipv4:
      - name: ipv4
        id: ipam-pool-abc123
        cidr: 10.0.0.0/8
    ipv6:
      ula:
        - name: ipv6-private
          id: ipam-pool-def456
          cidr: fd00:ec2::/48
      gua:
        - name: ipv6-public
          id: ipam-pool-xyz789
          cidr: 2600:1f26:47:c000::/52
```

## IPv6 Pool Sizing Reference

| Level | Netmask | Addresses | Use |
|-------|---------|-----------|-----|
| IPAM Pool | /52 | 4,096 /64s | Regional allocation |
| VPC | /56 | 256 /64s | Per-VPC allocation |
| Subnet | /64 | 18 quintillion | Per-subnet |
| Node Prefix | /80 | ~65k addresses | EKS prefix delegation |

## Development

```bash
make render              # Render default example
make test                # Run tests
make validate            # Validate compositions
make e2e                 # E2E tests
```

## License

Apache-2.0
