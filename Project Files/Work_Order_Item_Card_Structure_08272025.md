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