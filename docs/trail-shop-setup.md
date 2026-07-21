# Trail Shop Setup

Taruh setiap trail sebagai `Part` langsung di:

```text
ReplicatedStorage
└── Shared
    └── Trails
        ├── RedFire (Part)
        ├── BlueLightning (Part)
        └── ...
```

Nama Part menjadi ID persistent trail. Hindari mengganti nama Part setelah trail sudah dirilis.

## Attributes Part

- `Name` (string): nama yang tampil di shop. Fallback ke nama Part.
- `Price` atau `price` (number): harga coin. Fallback `100`.
- `Description` atau `description` (string): deskripsi shop.
- `Order` atau `LayoutOrder` (number): urutan card. Fallback `0`, lalu diurutkan berdasarkan harga.

## Isi Part

Sistem hanya menyalin direct child berikut ke `UpperTorso`:

- `Attachment` — seluruh descendant di dalam Attachment ikut tercopy.
- `ParticleEmitter` — bisa juga ditaruh langsung di Part.

Part template tidak ikut dicopy. Saat race selesai, player keluar dari race, respawn, atau mengganti trail, seluruh cosmetic trail yang lama dibersihkan otomatis.

```text
RedFire (Part)
├── FireAttachment (Attachment)
│   ├── Flame (ParticleEmitter)
│   └── Sparks (ParticleEmitter)
└── Smoke (ParticleEmitter) [opsional, direct child]
```

Posisi Attachment pada Part template akan menjadi posisi relatif terhadap `UpperTorso` setelah dicopy.
