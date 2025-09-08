#!/bin/bash

# Script to update old field names to new ones
# This will help get the project building

echo "🔄 Updating field names..."

# Update WorkOrder field names
find . -name "*.swift" -exec sed -i '' 's/\.WO_Type/\.workOrderType/g' {} \;
find . -name "*.swift" -exec sed -i '' 's/\.WO_Number/\.workOrderNumber/g' {} \;
find . -name "*.swift" -exec sed -i '' 's/\.imageURL/\.primaryImageURL/g' {} \;

# Update WO_Item field names
find . -name "*.swift" -exec sed -i '' 's/\.woItemId/\.itemNumber/g' {} \;
find . -name "*.swift" -exec sed -i '' 's/\.tagId/\.assetTagId/g' {} \;
find . -name "*.swift" -exec sed -i '' 's/\.cost/\.estimatedCost/g' {} \;

# Update Customer field names
find . -name "*.swift" -exec sed -i '' 's/\.phone/\.phoneNumber/g' {} \;

echo "✅ Field names updated!"
echo "Note: Some files may need manual review for edge cases"

