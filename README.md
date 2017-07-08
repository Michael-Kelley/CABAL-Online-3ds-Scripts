*I'm no longer working on these.  They are here purely for archival and showcase purposes*

---

## Set-up
1. Copy these scripts (including the \startup\ folder) to `${ACCOUNT_NAME}\AppData\Local\Autodesk\3dsMax\${MAX_VERSION}\ENU\scripts\`
2. Restart 3dsMax so that it runs the custom ui script.

## Requirements
* 3ds Max 2010 or newer

## Unsupported features
* Animations for models with magic key of 0x3EF03 or higher.  The animation list will still be populated, but no keys will be generated.
* Animation exporting works, but it's just a tiny bit funky.  I'll look into why the animations are a little different and will fix it soon.

## Usage notes
* To import an EBM/ECH, click the "Open..." button in the EBM properties panel (the one docked to the right with the Forge logo at the top).
* To export an EBM/ECH, click the "Save..." button in the EBM properties panel.
* You must complete all of the header information displayed in the EBM properties panel.  You will get an error when exporting if you don't provide values for each attribute, or you provide an incorrect value (ie. not adding a '%' after the scale).
* If your model contains bones, they MUST be assigned to a "Skin" modifier attached to at least the first mesh in your scene.  The importer will automatically create this modifier and the exporter will read from this modifier if it exists.
* If you want custom normals for your model, you need to add an "Edit Normals" modifier and store the normals there.  The importer will automatically create this modifier and the exporter will read from this modifier if it exists.
* All meshes need to be of the Editable_Mesh type.  If your meshes aren't in this format, just select each mesh in turn, right-click the viewport, go to "Convert to:" and select "Convert to Editable Mesh".
* Check "Export only mesh?" in the EBM options of the Forge toolbox in 3dsMax to only export the currently-selected mesh.  This is useful if you want to create or share custom armour.  The resulting .cmesh file can then be added directly to any ECH, or used to replace an existing piece of armour.
* Cabal uses a different coordinate system from 3ds Max.  To see how you need to orient your models, use existing Cabal models as references.