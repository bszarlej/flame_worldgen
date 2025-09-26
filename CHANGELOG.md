## 2.0.0

### Added
* Implemented `Tile` class to hold tile-related data
* Added debug rendering for `TileLayer`.
* Added `getRandomPosition()` method to `Chunk`.
* Added `worldSize`, `worldPosition` and `worldRect` properties to `Chunk`.
* Added tile world position to sprite selector callbacks.

### Changed
* Renamed `TileLayer` to `TileLayerComponent`.
* Renamed `chunkSize` to `size` and `chunkCoords` to `coords` inside `Chunk`.
- Refactored `processTile()` and `addOrUpdateTile()` to be private.
* Refactored to use global tile coordinates as keys instead the position.

### Fixed
* Fixed noise calculation to use global tile coordinates instead of world position.
- Ensured valid values for `chunkSize` and `tileSize`.

### Documentation
* Updated README and examples.

---

## 1.0.0

* Initial release