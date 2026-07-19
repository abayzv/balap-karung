# Manual Track Setup

Dokumen ini adalah kontrak pembuatan track manual untuk prototype Balap Karung.

## Struktur DataModel

Rojo menyediakan dua folder berikut:

```text
ServerStorage
└── Tracks
    └── Kampung                    [tag: BalapKarungTrack]
        ├── Geometry
        ├── Decorations
        └── Markers
            ├── Spawn01            [tag: BalapKarungSpawn, LaneIndex: 1]
            ├── Spawn02            [tag: BalapKarungSpawn, LaneIndex: 2]
            ├── ...
            ├── Spawn10            [tag: BalapKarungSpawn, LaneIndex: 10]
            ├── TargetPart01       [tag: MoveTarget, LaneIndex: 1]
            ├── TargetPart02       [tag: MoveTarget, LaneIndex: 2]
            ├── ...
            ├── TargetPart10       [tag: MoveTarget, LaneIndex: 10]
            └── Finish             [tag: BalapKarungFinish]

Workspace
└── ActiveTrack
    └── Kampung                    [dibuat otomatis saat Play]
```

`ServerStorage/Tracks` menyimpan template. Jangan meletakkan model yang sedang diedit di
`Workspace/ActiveTrack`, karena isi folder tersebut dibersihkan dan di-clone ulang oleh server.

## Model Track

Pilih Model track utama dan tambahkan tag `BalapKarungTrack` melalui Tag Editor. Tambahkan
attributes berikut pada Model:

| Attribute | Type | Wajib | Contoh | Fungsi |
|---|---|---:|---|---|
| `TrackId` | String | Ya | `Kampung` | ID unik untuk code dan voting |
| `DisplayName` | String | Ya | `Lapangan Kampung` | Nama yang ditampilkan ke pemain |

## Spawn Lane

Buat maksimal 10 Part marker di dalam Model track. Untuk playtest, track tetap dapat berjalan dengan
jumlah marker yang lebih sedikit. Urutkan lane dari kiri ke kanan ketika melihat ke arah finish.

Setiap Part marker harus memiliki:

- Tag `BalapKarungSpawn`.
- Number attribute `LaneIndex` dari `1` sampai `10`, tanpa duplikat.
- `Anchored = true`.
- `CanCollide = false`.
- `CanTouch = false`.
- `CanQuery = false`.
- `Transparency = 1` setelah penempatan selesai.
- Rotasi spawn tidak menentukan arah lari. Arah setiap lane ditentukan oleh pasangan `MoveTarget`.

Nama Part bebas. `Spawn01` sampai `Spawn10` hanya rekomendasi agar Explorer mudah dibaca.

Server mengacak pemain setiap race dan mengambil spawn dari bagian tengah. Contoh: dua marker cukup
untuk playtest dua pemain; sepuluh pemain memakai seluruh spawn pada track final.

## Move Target

Setiap spawn harus memiliki satu BasePart pasangan bertag `MoveTarget`. Beri target `LaneIndex` yang
sama dengan spawn pasangannya:

```text
Spawn01      LaneIndex = 1  →  TargetPart01  LaneIndex = 1
Spawn02      LaneIndex = 2  →  TargetPart02  LaneIndex = 2
```

Letakkan target pada lane yang sama dan tepat di tengah garis finish. Arah lari dihitung dari posisi
spawn menuju posisi target. Target juga menjadi pengaman finish jika karakter melewati trigger di
antara frame. Nama Part tidak dibaca code; pasangan hanya ditentukan oleh `LaneIndex`.

Atur setiap target menjadi `Anchored = true`, `CanCollide = false`, `CanTouch = false`,
`CanQuery = false`, dan `Transparency = 1`. Jumlah MoveTarget harus sama dengan jumlah spawn.

## Finish

Buat satu Part melintang di garis finish dan tambahkan tag `BalapKarungFinish`.

Atur marker finish sebagai berikut:

- Tepat satu finish per Model track.
- `Anchored = true`.
- `CanCollide = false`.
- `CanTouch = false`.
- `CanQuery = false`.
- `Transparency = 1`.
- Letakkan pusat Part pada posisi progress yang dianggap selesai.
- Bentangkan Part melintasi seluruh lebar lane.
- Beri ketebalan sekitar 4–6 studs pada arah lari agar karakter tidak melewatinya di antara frame.

Finish visual boleh berupa Model terpisah dan tidak perlu tag. Hanya marker transparan yang dibaca
gameplay.

## Cara Kerja Runtime

1. Server mencari Model bertag `BalapKarungTrack` di `ServerStorage/Tracks`.
2. Track dipilih secara acak dari shuffle bag agar seluruh track bergantian tanpa pengulangan langsung.
3. Template di-clone ke `Workspace/ActiveTrack` sebelum countdown lobby 30 detik dimulai.
4. Server memasangkan spawn dan MoveTarget berdasarkan `LaneIndex`.
5. Arah serta panjang setiap lane dihitung dari spawn menuju MoveTarget pasangannya.
6. Karakter dinyatakan finish saat tubuhnya overlap dengan Part finish atau sudah melewati
   MoveTarget pada lane miliknya.

## Area Antrean Lobby

- Buat sebuah `BasePart` di `Workspace` dan beri tag `StartPart`.
- Ukuran dan rotasi Part menjadi volume pendeteksi pemain; `HumanoidRootPart` harus berada di dalam
  volume tersebut.
- Countdown hanya berjalan selama minimal dua pemain berada di dalam gabungan seluruh StartPart.
- Attribute `InStartArea` pada Player dan `PlayersInStartArea` pada Workspace tersedia untuk debug.

Attributes runtime berikut tersedia pada `Workspace` untuk debugging:

- `ActiveTrackId`
- `ActiveTrackName`
- `ActiveTrackLength`
- `TrackSetupError`

Jika setup salah, race tidak dimulai dan penjelasannya muncul pada `TrackSetupError` serta Output.

## Checklist Sebelum Playtest

- [ ] Model berada di `ServerStorage/Tracks`.
- [ ] Model memiliki tag `BalapKarungTrack`.
- [ ] `TrackId` dan `DisplayName` sudah diisi.
- [ ] Ada maksimal 10 Part bertag `BalapKarungSpawn` (dua sudah cukup untuk playtest).
- [ ] Semua spawn memiliki `LaneIndex` unik dari 1 sampai 10.
- [ ] Setiap spawn memiliki satu `MoveTarget` dengan `LaneIndex` yang sama.
- [ ] Jumlah spawn dan MoveTarget sama.
- [ ] Semua MoveTarget berada tepat di tengah garis finish pada lane masing-masing.
- [ ] Ada tepat satu Part bertag `BalapKarungFinish`.
- [ ] Part finish melintang menutupi seluruh lane dan memiliki ketebalan 4–6 studs.
- [ ] Semua geometry track sudah Anchored.
