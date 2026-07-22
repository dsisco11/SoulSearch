# Component Test Support

Place reusable DwarfSpec fixture factories, callback recorders, and live-unit
selection helpers in this directory as ordinary `.lua` modules. DwarfSpec does
not discover these support files as specs; each component spec imports only the
helpers it needs.

Support code must not mutate fortress units or persist UI configuration merely
to prepare a test fixture.
