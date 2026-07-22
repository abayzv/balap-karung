# World Leaderboard Setup

Setiap model leaderboard menggunakan tag dan attributes berikut:

```text
Leaderboard (Model) [tag: Leaderboard]
├── View (Part) [tag: LeaderboardView]
├── Avatar1 (Part) [tag: LeaderboardAvatar, Index = 1]
├── Avatar2 (Part) [tag: LeaderboardAvatar, Index = 2]
└── Avatar3 (Part) [tag: LeaderboardAvatar, Index = 3]
```

## Attributes model

- `Data` (string): `win`, `playtime`, `winstreak`, `bestwinstreak`, atau `coins`.
- `ItemCount` (number): jumlah ranking, maksimum 100.
- `Version` (number): ganti angka ini jika leaderboard perlu dimulai dari data global kosong.
- `Source` (string, opsional): `Auto`, `Leaderstats`, atau `Profile`.

`Auto` membaca Player attribute yang disinkronkan dari ProfileStore terlebih dahulu, lalu fallback ke leaderstats. Data global disalin ke OrderedDataStore secara berkala dan hanya ditulis saat berubah. Di Studio dengan mock ProfileStore, leaderboard memakai pemain dalam server aktif tanpa mengakses DataStore.

Nilai di bawah `GameConfig.leaderboard.minimumValue` tidak ditampilkan. Default-nya `1`, sehingga pemain dengan nilai `0` tidak mendapat card atau avatar podium.
