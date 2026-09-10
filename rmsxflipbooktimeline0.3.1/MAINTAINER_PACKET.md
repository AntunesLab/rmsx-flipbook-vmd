# VMD maintainer review packet

RMSX / Flipbook Timeline is a separately named Tcl/Tk extension combining native
RMSX/Shift-Map/1-lDDT and linked residue-by-time analysis with molecular views.
The primary review target is VMD2.0b1 on Apple Silicon. Existing Timeline is
preserved; replacement of a built-in plugin is not part of this release.

The ordinary user menu callback is `rmsxflipbooktimeline`. The source release
contains installation/registration helpers, small examples, complete test
classification, fixture provenance, MIT licensing and VMD plugin notices.

Suggested meeting: follow docs/MEETING.md, inspect single-chain and multichain
results, exercise cancellation/error recovery and export, then discuss API,
menu placement, support expectations and scientific conventions.

Items requiring external evidence or maintainer decisions:

- Official bundling/menu location and contribution requirements.
- Windows, Linux and Intel macOS graphical VMD certification.
- The stable non-beta VMD build(s) expected for public support.
- Hosted VMD runner provisioning and licensed runtime availability.
- Final review of scientific parity, legacy ambiguity handling and notices.

Keep completed local tests separate from pending external checks. No approval,
endorsement or cross-platform pass is implied by this packet's existence.
