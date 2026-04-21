#!/bin/bash

# Script to regenerate app icons with new configuration
# Run this from the eswari_crm_mobile directory

echo "Regenerating app icons..."
flutter pub get
flutter pub run flutter_launcher_icons

echo "Done! Icons have been regenerated with white background and smaller size."
echo "Please rebuild the app to see the changes."
