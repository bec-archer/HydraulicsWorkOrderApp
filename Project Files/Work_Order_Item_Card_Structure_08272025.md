Work Order Item Card (Gray background with rounded corners)
├── Item Header (HStack)
│   ├── Left: Type/ID info (VStack)
│   │   ├── "Cylinder" (Text)
│   │   └── "Tag: XXX" + "ID: XXX" (HStack)
│   ├── Center: Reasons for Service (VStack) - NEW
│   │   ├── "Reasons for Service" (Text)
│   │   └── Checkboxes for each reason
│   └── Right: Status Badge (Button)
│
└── Main Content Area (GeometryReader with fixed height: 400px)
	└── HStack (spacing: 16)
		├── Images Section (45% width)
		│   ├── Main Image (200px height)
		│   └── Thumbnail Grid (2x2 HStack)
		│
		└── Notes & Status Section (55% width)
			├── "Notes & Status" (Text)
			├── Status History (VStack)
			├── Notes (VStack)
			└── "Add Note/Image" Button (at bottom)
			
			Key Containment Details:
			Overall Card: Uses .padding(16) and .background(Color(.systemGray6))
			GeometryReader: Creates a fixed 400px height container that controls the main content area
			HStack: Contains the two main sections with spacing: 16 between them
			Images Section:
			Width: geometry.size.width * 0.45 (45% of available space)
			Contains main image + thumbnail grid
			Notes & Status Section:
			Width: geometry.size.width * 0.55 (55% of available space)
			Contains all notes content + button
			
Work Order Item Card (Gray background with rounded corners)
			├── Item Header (HStack)
			│   ├── Left: Type/ID info (VStack)
			│   │   ├── "Cylinder" (Text)
			│   │   └── "Tag: XXX" + "ID: XXX" (HStack)
			│   ├── Center: Reasons for Service (VStack) - NEW
			│   │   ├── "Reasons for Service" (Text)
			│   │   └── Checkboxes for each reason
			│   └── Right: Status Badge (Button)
			│
			└── Main Content Area (GeometryReader with fixed height: 400px)
				└── HStack (spacing: 16)
					├── Images Section (45% width)
					│   ├── Main Image (200px height)
					│   └── Thumbnail Grid (2x2 HStack)
					│
					└── Notes & Status Section (55% width)
						├── "Notes & Status" (Text)
						├── Status History (VStack)
						├── Notes (VStack)
						└── "Add Note/Image" Button (at bottom)
						

┌───────────────────────────────────────────────────────────────────────────────┐
│                                 CARD CONTAINER                                │
├───────────────────────────────┬───────────────────────────────┬───────────────┤
│           Type/ID             │   Reasons for Service (Text)  │  Status Badge │
│  • Tag: XXX   • ID: XXX       │   [ ] Reason 1                │   [ Status ]  │
│                               │   [ ] Reason 2                │               │
│                               │   [ ] Reason 3                │               │
├───────────────────────────────┴───────────────────────────────┴───────────────┤
│                          CONTENT SECTION (Split)                              │
├─────────────────────────────────────┬─────────────────────────────────────────┤
│        Images Section (45%)         │      Notes & Status Section (55%)       │
│                                     │                                         │
│  ┌───────────── Main Image ───────┐ │  • Status History                       │
│  │          (200px height)        │ │     - 08/27 Checked In                  │
│  └────────────────────────────────┘ │     - 08/27 In Progress                 │
│                                     │                                         │
│  ┌────────────────────────────────┐ │  • Notes                                │
│  │  ┌───────────┬───────────┐     │ │     - Customer requested rush           │
│  │  │ Thumbnail │ Thumbnail │     │ │     - Seal kit on order                 │
│  │  ├───────────┼───────────┤     │ │                                         │
│  │  │ Thumbnail │ Thumbnail │     │ │  [ Add Note / Image ] Button            │
│  │  └───────────┴───────────┘     │ │                                         │
│  └────────────────────────────────┘ │                                         │
│                                     │                                         │
└─────────────────────────────────────┴─────────────────────────────────────────┘

