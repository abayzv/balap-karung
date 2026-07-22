# Dynamic UI Scale

Gunakan sistem ini untuk memilih `UIScale.Scale` berdasarkan platform tanpa membuat script khusus
untuk setiap GUI.

## Setup

1. Tambahkan object `UIScale` pada GUI yang ingin dibuat responsif.
2. Beri `UIScale` tersebut tag `DynamicScale` melalui Tag Editor.
3. Tambahkan dua Number attributes langsung pada `UIScale`:

| Attribute | Type | Contoh | Digunakan pada |
|---|---|---:|---|
| `Mobile` | Number | `1.15` | Android dan iOS |
| `Desktop` | Number | `1.7` | PC, Mac, console, dan Studio |

Controller hanya mengubah property `Scale`. Size, Position, AnchorPoint, dan desain parent tetap
mengikuti setting yang dibuat di Studio.

Jika attribute untuk platform aktif belum diisi atau bukan Number, nilai `Scale` yang sudah ada tidak
diubah. Attribute dapat diedit saat runtime dan controller akan langsung menerapkan nilai terbaru.

## Pulse

`DynamicScale` hanya menentukan base scale. Efek khusus seperti pulse On Fire tetap dikendalikan oleh
controller fitur dan dihitung relatif terhadap base scale tersebut. Contoh: base `1.7` dengan pulse
`1.06×` bergerak antara `1.7` dan `1.802`.
