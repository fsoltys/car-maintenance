# Car Maintenance — Backend + Database

Repozytorium zawiera aplikację wspomagającą zarządzanie samochodem osobowym, przygotowaną w ramach pracy inżynierskiej. Praca skłąda się z  backendu FastAPI, bazy danych PostgreSQL i aplikacji mobilnej (Flutter) 

## Szybki start (Docker Compose)

- Plik `docker-compose.yml` w katalogu projektu uruchamia kontenery z PostgreSQL i aplikacją FastAPI.
- Aby uruchomić (lokalnie) w trybie deweloperskim/produkcyjnym:

```powershell
# z katalogu projektu
docker compose up --build -d
# aby zobaczyć logi backendu
docker compose logs -f backend
# zatrzymanie
docker compose down
```

Jeżeli chcesz uruchomić bez budowania (używa istniejących obrazów):

```powershell
docker compose up -d
```

### Dostęp i adresy

- Backend nasłuchuje na porcie `8000` (mapowany na host):
  - API: http://localhost:8000
  - Interaktywna dokumentacja OpenAPI (Swagger UI): http://localhost:8000/docs
  - Redoc: http://localhost:8000/redoc

### Pliki konfiguracyjne / zmienne środowiskowe

- Backend czyta ustawienia z `.env` (lokalnie). Przykładowe zmienne, których używa aplikacja (w `app/config.py`):

```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=car_db
DB_USER=car_user
DB_PASSWORD=securepassword

JWT_SECRET_KEY=replace_with_a_secret
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
ENVIRONMENT=dev
```

## Struktura katalogów

- `API/` — źródła backendu FastAPI
  - `main.py` — punkt wejścia aplikacji
  - `app/` — kod źródłowy (route'y, schematy, zależności)
- `Database/` — skrypty inicjujące bazę danych
  - `init/` — skrypty SQL uruchamiane przy inicjalizacji DB (w `docker-entrypoint-initdb.d/`)
- `Flutter-App/` — kod frontendu (WIP)

## API
Najważniejsze endpointy, niektóre z nich wymagają autoryzacji (Bearer token JWT).

| Metoda | Ścieżka | Opis |
|--------|---------|------|
| GET | `/users/me` | Pobranie profilu zalogowanego użytkownika |
| GET | `/meta/health` | Health check API + DB connection |
| GET | `/meta/version` | Informacje o wersji serwisu |
| POST | `/auth/register` | Rejestracja użytkownika — zwraca profil (UserOut) |
| POST | `/auth/login` | Logowanie — zwraca token dostępu (Bearer) |
| GET | `/vehicles` | Lista pojazdów (własne + współdzielone) |
| POST | `/vehicles` | Utworzenie pojazdu |
| GET | `/vehicles/{vehicle_id}` | Pobranie szczegółów pojazdu |
| PATCH | `/vehicles/{vehicle_id}` | Częściowa aktualizacja pojazdu |
| DELETE | `/vehicles/{vehicle_id}` | Usunięcie pojazdu |
| GET | `/vehicles/{vehicle_id}/shares` | Lista współdzielących (tylko OWNER) |
| POST | `/vehicles/{vehicle_id}/shares` | Dodanie lub aktualizacja udziału (owner only) |
| PATCH | `/vehicles/{vehicle_id}/shares/{user_id}` | Zmiana roli współdzielącego |
| DELETE | `/vehicles/{vehicle_id}/shares/{user_id}` | Usunięcie współdzielenia |
| GET | `/vehicles/{vehicle_id}/fuels` | Pobranie konfiguracji paliw pojazdu |
| PUT | `/vehicles/{vehicle_id}/fuels` | Zastąpienie konfiguracji paliw pojazdu |

## Baza danych

Skrypty znajdują się w `Database/init/` i są montowane do kontenera PostgreSQL (katalog `/docker-entrypoint-initdb.d/`) — pliki uruchamiają się tylko przy pierwszym tworzeniu wolumenu danych.

- `001-init.sql` — podstawowa inicjalizacja schematu, tworzenie schematu `car_app`, ewentualne rozszerzenia PostgreSQL (uuid-ossp itp.) i role użytkowników.
- `002-tables.sql` — definicje tabel (`users`, `vehicles`, `vehicle_shares`, itp.) oraz indeksów i constraints.
- `003-auth-users.sql` — funkcje/procedury związane z uwierzytelnianiem i użytkownikami (np. `fn_register_user`, `fn_get_user_for_login`, helpery do haseł, role).
- `004-vehicles.sql` — funkcje i procedury związane z tworzeniem/aktualizacją pojazdów (np. `fn_create_vehicle`, `fn_update_vehicle`, tabela `vehicles`).
- `005-vehicle-shares.sql` — funkcje obsługi współdzielenia pojazdów (np. `fn_add_vehicle_share`, `fn_remove_vehicle_share`, `fn_update_vehicle_share_role`).
- `006-meta.sql` — dodatkowe tabele meta, np. do wersjonowania schematu, słowników lub danych pomocniczych.
- `007-vehicle-fuel-config.sql` — konfiguracja paliw/zbiornika i funkcje pomocnicze związane z profilem paliwa i obliczeniami.

## Frontend (WIP)