┌──────────────────────────────────────────────────────────────┐
│                    CONTAINER FOR IMAGES                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                   PRIMARY IMAGE (W × H)                │  │
│  │   • Full-width inside Container 1                      │  │
│  │   • Image Aspect should be 1:1 square with rounded	    │  │
│  │     corners                                            │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │         CONTAINER 2 — SAME WIDTH AS PRIMARY IMAGE      │  │
│  │   (Thumbnail Grid; width locked to the primary’s width)│  │
│  │                                                        │  │
│  │  ┌───────────┬───────────┐                             │  │
│  │  │ THUMB 1   │ THUMB 2   │                             │  │
│  │  │ (square)  │ (square)  │                             │  │
│  │  ├───────────┼───────────┤                             │  │
│  │  │ THUMB 3   │ THUMB 4   │  ← 2 columns, wraps rows    │  │
│  │  │ (square)  │ (square)  │                             │  │
│  │  └───────────┴───────────┘                             │  │
│  │  Notes:                                                │  │
│  │  • All thumbnails are **cropped to 1:1 (square)**.     │  │
│  │  • Grid **width = primary image width**.               │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘