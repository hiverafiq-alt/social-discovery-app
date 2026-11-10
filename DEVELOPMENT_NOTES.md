# Preserved behavior and release boundaries

- Both DEMO_MODE and WEB_PREVIEW must be true for this browser preview. Production must not silently use fictional identities.
- Preview starts at discovery and labels sample profiles. It never requests native capture permissions or uploads sample bill evidence.
- Invitations cannot be accepted after expiry; expiry wins at the boundary. Terminal decisions cannot be reversed. Only recipients accept incoming invitations.
- Chat opens only after acceptance; blocking removes discovery and revokes chat. Repeated invitation keys do not create duplicates.
- Intro duration/age boundaries and request-redaction behavior have existing tests. Maintain those tests when changing onboarding or media flows.
- Browser preview skips native playback telemetry. Custom native event channels and device behavior require real platform implementation/testing.
- No live payment adapter exists. Simulated contribution state is not payment processing or escrow.
- This recovered package contains Flutter UI/domain/repository source and tests. The original mobile release package's backend and native distribution assets were not recovered here; no historical whole-system test count is claimed for this repository.
- A renamed source build must be rebuilt. Old compiled bundles can contain previous branding or endpoints and are excluded.
