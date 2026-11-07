# HexGym body model

The muscle body of the HexGym app, in two versions, male and female. Each is a 3D body made with Meshy
from our own reference, bound to one shared skeleton and painted with 36 regions per side. The regions
come from the MuscleMap figures plus seven v2 regions drawn by rules on the skeleton. Both bodies use the
same region ids, so one map from exercise to regions serves both.

The exercise media licensed from Gym visual is never opened or used here.

## Layout

| Folder | What is in it |
|---|---|
| `blender/` | Blender scripts, run as `Blender -b <file.blend> -P <script> -- <args>` |
| `musclemap/` | The MuscleMap figures (`male.json`, `male.svg`, `female.json`), the label table and the region scripts |
| `body/` | Scripts for the atlas images (renders, labelled plates, activation crops), written to `work/atlas` |
| `ref/`, `ref_f/` | The four views sent to Meshy multi-image to 3D, and the reference they were drawn from |
| `regions/` | The map from exercise to regions: the generator, its tests and its two JSON files, plus the compact JSON it writes into the HexBody package (`apple/Packages/HexBody`, see `regions/README.md`) |
| `work/` | Generated and heavy files, **not in git** |

`musclemap/labels.json` is the one id table for both bodies (229 rows). Pieces drawn only on the female
figure carry `"fig": "female"`. New rows are always appended, so ids never move. `labels_f.json` is the
same table with the female figure's frame, written by `raster.py` for `project.py`.

`raster.py` writes both files indented, one value per line, so a changed id shows up in the diff.
`labels.json` was rewritten that way with the standard library alone (only the whitespace changed);
`labels_f.json` gets the same indentation the next time step 5 runs for the female body.

## work/ (not in git)

| File, per body (`work/body`, `work/body_f`) | Made by |
|---|---|
| `meshy-body.glb` | Meshy, the source mesh |
| `hexbody.blend` | step 1, the mesh fitted to the skeleton |
| `hexbody_rig.blend` | steps 2 and 3, rigged, remeshed, triangulated |
| `posed.npz` | step 4, vertices, normals, triangles and joints in the MuscleMap pose |
| `mm_final.npy` | step 6, the region of every vertex (v1) |
| `mm_v2.npy` | step 7, the region of every vertex (v2), the file the app will use |
| `seams_v2.npz` | step 7, the borders between regions, used by the renders |
| `out/` | step 8, renders |

`work/anim/squat.blend` is the squat scene from the animation test. Its skeleton (SMPL-H joint layout, from
Meshy text to motion) is the one both bodies hang on.

The files in `work/` are the reference versions, and today they exist only on the machine that made
them. Where the backup lives is issue #10 in the fork.

## Build order

Run from `scripts/hexbody`. The commands below build the female body. The comments say where the male
body differs.

```sh
B=/Applications/Blender.app/Contents/MacOS/Blender
W=work/body_f                                      # male: work/body

# 1. Fit the Meshy mesh to the skeleton (writes fit-front.png and fit-side.png to check)
$B -b work/anim/squat.blend -P blender/fit_body.py -- $W/meshy-body.glb $W/hexbody.blend $W/fit

# 2. Move knees, ankles, elbows and wrists to the joint centres of this mesh, then rig
#    male: no HEX_JB (its values are the defaults in remap_body.py)
HEX_JB=$PWD/blender/joints_female.json $B -b $W/hexbody.blend -P blender/remap_body.py -- $W/hexbody_rig.blend

# 3. Even mesh (3.5 mm voxels), then triangles
cp $W/hexbody_rig.blend $W/hexbody_rig_dec.blend
$B -b $W/hexbody_rig_dec.blend -P blender/remesh_body.py -- 0.0035 $W/hexbody_rig.blend
$B -b $W/hexbody_rig.blend -P blender/tri_body.py

# 4. Pose like the MuscleMap figure and export
#    male: no HEX_ELBOW, arms at 17.4
HEX_ELBOW=18 $B -b $W/hexbody_rig.blend -P blender/pose_export.py -- 11.4 $W/posed.npz

# 5. MuscleMap figure to pixels, then onto the body (male: HEX_FIG=male or unset)
HEX_FIG=female python3 musclemap/raster.py
HEX_FIG=female python3 musclemap/project.py $W/posed.npz $W/mm_labels.npy

# 6. Clean the borders and make the sides match
python3 musclemap/clean.py $W/posed.npz $W/mm_labels.npy $W/mm_c1.npy 0
python3 musclemap/refine.py $W/posed.npz $W/mm_c1.npy $W/mm_c2.npy 0.02 6
python3 musclemap/clean.py $W/posed.npz $W/mm_c2.npy $W/mm_final_pre.npy 12
python3 musclemap/sym.py $W/posed.npz $W/mm_final_pre.npy $W/mm_final.npy

# 7. The seven v2 regions, then the seams
HEX_FIG=female python3 musclemap/v2.py $W/posed.npz $W/mm_final.npy $W/mm_v2.npy
python3 musclemap/seams.py $W/posed.npz $W/mm_v2.npy $W/seams_v2.npz

# 8. Atlas images (into work/atlas, or HEX_ATLAS)
body/render.sh female
PLATE_FIG=female python3 body/plate.py              # male: PLATE_V2=1 python3 body/plate.py
python3 body/crop_acts.py female
```

The female joint centres in `blender/joints_female.json` were picked by hand from cross-sections:
`blender/dump_body.py` exports the fitted vertices and `blender/joints.py` prints leg and arm profiles
next to the male ones.

To see the regions on the body:
`$B -b $W/hexbody_rig.blend -P blender/show_labels_v2.py -- $W/mm_v2.npy $W/labels` writes one image per view.

## Settings

| Variable | Used by | Meaning |
|---|---|---|
| `HEX_FIG` | `raster.py`, `project.py`, `v2.py` | `male` (default) or `female` |
| `HEX_JB` | `remap_body.py` | JSON with the joint centres, left side |
| `HEX_ELBOW` | `pose_export.py` | extra outward bend of the forearms, degrees |
| `HEX_SEAMS` | `bodylook.py` | seams file for the renders (`render.sh` sets it) |
| `HEX_ANCHORS` | `bodymodel.py` | also write the anchors `plate.py` needs |
| `HEX_RIG` | `hexbody_in.py` | which body to bring into an exercise scene |
| `PLATE_V2`, `PLATE_FIG` | `plate.py` | male v2 plates, or the female ones |
| `HEX_ATLAS` | `plate.py`, `crop_acts.py` | output folder, `work/atlas` by default |
| `BLENDER`, `OUT`, `RES`, `SAMPLES` | `render.sh` | Blender binary, output folder, size, samples |

The activation names in `bodylook.py` (`supino`, `puxada` and so on) are render examples. The app's map
from exercise to regions is built from the exercise catalogue, in `regions/`.

## Inspection and history

Not part of the build order:

- `blender/inspect_glb.py`, `blender/export_verts.py` and `blender/ruler.py` were used while fitting the
  bodies: what is inside a GLB, the vertices and normals as a `.npy`, and landmark heights read off a
  ruler.
- `blender/show_labels.py` is the v1 debug view; `show_labels_v2.py` replaces it.
- `musclemap/labels_v1.json` is the v1 id table, kept for history. `labels.json` keeps its 203 rows at
  the same ids; only the rotator cuff moved, from `upper-back` to `deltoids`.
- `musclemap/fields.py` is the earlier way to draw the seams (distance fields per vertex). The renders
  now use `seams.py`, which stores them per triangle corner.
- `musclemap/male.svg` is the MuscleMap male figure as an SVG, for viewing. The scripts read `male.json`.

## What was checked (31 October 2026)

- **Tools:** Blender 5.1.2, Python 3.13.11, numpy 2.5.3, scipy 1.18.1 and Pillow 12.3.0. "Vertex for
  vertex" below holds for these versions.
- **Female:** steps 5 to 7, run from this folder, reproduce `work/body_f` vertex for vertex.
- **Male:** steps 5 and 7 reproduce it too, but its `mm_final.npy` was projected before step 3
  triangulated the mesh. Running steps 5 and 6 again now moves about 1.4% of the border vertices.
  Keep `work/body/mm_final.npy` and rebuild only if the body itself changes.
- **Atlas:** `plate.py` reproduces both plate files, and `crop_acts.py` reproduces the female crops. The
  male v2 crops in the atlas came from an earlier pass of the framing rule, so running it again frames
  them a little differently.

## Credits

- **MuscleMap** by Melih Colpan, MIT licence ([github.com/melihcolpan/MuscleMap](https://github.com/melihcolpan/MuscleMap)).
  `male.json`, `male.svg` and `female.json` are its front and back figure paths. The licence text is in
  `musclemap/LICENSE-MuscleMap`.
- **References:** `ref/referencia-corpo.jpg` is the reference Lipe supplied, and the four views in `ref/` are
  cut from it. `ref_f/` was made from it with Meshy image to image. How the reference itself was made is
  still to be written down (issue #10 in the fork).
- **Meshy** also made both body meshes and the squat motion.
- Everything else here was written for HexGym.
