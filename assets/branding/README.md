# CAF4U Aircraft Companion icon

User-directed composition from the supplied `CAF4U_Symbol_Approved.png`, 31 October 2026.
The supplied Travel Companion light icon is a layout reference only.

The master raster is preserved: no regeneration, tracing, recolouring or cleanup.
Only two black topical pictograms are composited: radar on the left, aeroplane on the right.
`compose_icon.py` (Python + Pillow) reproduces the composition and checks every source pixel outside the pictogram mask.
The source SHA-256 is `c067aa5cd622a326b20dd8e33eb280666a2300460e90dd54d9036826d45f6c03`.

`CAF4U_Aircraft_Companion_Symbol.png` retains transparency. The Light PNG is the same composition over white.
Android launcher exports scale this composition, retain padding, and use a white square canvas.
The app label is CAF4U Aircraft Companion; no text is embedded in the launcher icon.
