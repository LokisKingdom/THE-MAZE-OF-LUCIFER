# Godot 4 Searchable Archive

## Install

1. Copy the `archive_browser` folder into the root of your Godot project.
2. Create `res://archive/`.
3. Put TXT, PDF, JPG, JPEG, PNG, and WEBP files there. Subfolders work.
4. Drag `res://archive_browser/searchable_archive.tscn` into your main game scene.
5. Run the game and press **F6** to open or close the archive.

## Features

- Recursive folder scanning
- Search by filename, folder, relative path, and TXT contents
- Internal TXT reader
- Internal JPG/JPEG/PNG/WEBP viewer
- Image zoom controls
- Folder and type filters
- PDF listing and external opening in the system PDF reader

## Export setting

In your Godot export preset, add this under:

`Resources -> Filters to export non-resource files/folders`

```text
archive/**/*.txt, archive/**/*.pdf, archive/**/*.jpg, archive/**/*.jpeg, archive/**/*.png, archive/**/*.webp
```

Without that setting, documents may appear in the editor but be missing from exported builds.

## Open from your own button

```gdscript
$SearchableArchive.toggle_archive()
```

PDFs are opened externally because ordinary Godot 4 has no built-in PDF renderer. Internal PDF rendering requires a separate native PDF plugin.
