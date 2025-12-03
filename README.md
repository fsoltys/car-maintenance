# Car Maintenance — System zarządzania samochodem

Repozytorium zawiera pełną aplikację wspomagającą zarządzanie samochodem osobowym, przygotowaną w ramach pracy inżynierskiej. System składa się z backendu FastAPI, bazy danych PostgreSQL oraz aplikacji mobilnej Flutter. 

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
- `Flutter-App/` — aplikacja mobilna Flutter
  - `lib/` — kod źródłowy aplikacji
    - `core/` — podstawowe klasy (API client, theme, constants)
    - `features/` — funkcjonalności aplikacji (auth, fuel, expenses, services, reminders, home)
    - `models/` — modele danych
    - `services/` — serwisy komunikacji z API

## API Backend

Backend FastAPI udostępnia RESTful API z autoryzacją JWT. Aplikacja jest podzielona na moduły funkcjonalne:

### Główne grupy endpointów

- **Autoryzacja i użytkownicy** (`/auth`, `/users`)
  - Rejestracja i logowanie użytkowników
  - Zarządzanie profilem użytkownika
  - Tokeny JWT (Bearer authentication)

- **Pojazdy** (`/vehicles`)
  - CRUD operacje na pojazdach
  - Współdzielenie pojazdów z innymi użytkownikami (role: OWNER, EDITOR, VIEWER)
  - Konfiguracja paliw i parametrów technicznych
  - Obliczanie średniego spalania

- **Tankowania** (`/vehicles/{vehicle_id}/fuelings`)
  - Historia tankowania
  - Śledzenie kosztów paliwa
  - Automatyczne obliczanie spalania (pełny/częściowy bak)
  - Wsparcie dla różnych cykli jazdy i typów paliwa

- **Wydatki** (`/vehicles/{vehicle_id}/expenses`)
  - Ewidencja wydatków związanych z pojazdem
  - Kategoryzacja (paliwo, serwis, ubezpieczenie, itp.)
  - Analiza kosztów eksploatacji

- **Serwis** (`/vehicles/{vehicle_id}/services`)
  - Historia napraw i przeglądów
  - Śledzenie kosztów serwisowych
  - Przypisywanie do wykonawców

- **Przypomnienia** (`/vehicles/{vehicle_id}/reminders`)
  - Przypomnienia o przeglądach, ubezpieczeniu, wymianach
  - Przypomnienia oparte na czasie lub przebiegu
  - Automatyczne powiadomienia

- **Meta** (`/meta`)
  - Health check i status systemu
  - Słowniki danych (kategorie wydatków, typy paliw, cykle jazdy)
  - Wersjonowanie API

### Dokumentacja API

Pełna interaktywna dokumentacja dostępna po uruchomieniu backendu:
- Swagger UI: http://localhost:8000/docs
- Redoc: http://localhost:8000/redoc

## Baza danych

Skrypty znajdują się w `Database/init/` i są montowane do kontenera PostgreSQL (katalog `/docker-entrypoint-initdb.d/`) — pliki uruchamiają się tylko przy pierwszym tworzeniu wolumenu danych.

- `001-init.sql` — podstawowa inicjalizacja schematu, tworzenie schematu `car_app`, ewentualne rozszerzenia PostgreSQL (uuid-ossp itp.) i role użytkowników.
- `002-tables.sql` — definicje tabel (`users`, `vehicles`, `vehicle_shares`, itp.) oraz indeksów i constraints.
- `003-auth-users.sql` — funkcje/procedury związane z uwierzytelnianiem i użytkownikami (np. `fn_register_user`, `fn_get_user_for_login`, helpery do haseł, role).
- `004-vehicles.sql` — funkcje i procedury związane z tworzeniem/aktualizacją pojazdów (np. `fn_create_vehicle`, `fn_update_vehicle`, tabela `vehicles`).
- `005-vehicle-shares.sql` — funkcje obsługi współdzielenia pojazdów (np. `fn_add_vehicle_share`, `fn_remove_vehicle_share`, `fn_update_vehicle_share_role`).
- `006-meta.sql` — dodatkowe tabele meta, np. do wersjonowania schematu, słowników lub danych pomocniczych.
- `007-vehicle-fuel-config.sql` — konfiguracja paliw/zbiornika i funkcje pomocnicze związane z profilem paliwa i obliczeniami.

## Aplikacja mobilna Flutter

Aplikacja mobilna napisana we Flutter umożliwia kompleksowe zarządzanie pojazdem z poziomu smartfona (Android/iOS).

### Główne funkcjonalności

#### Ekran główny (Home)
- Przegląd kluczowych informacji o pojeździe
- Ostatnie tankowanie i średnie spalanie
- Nadchodzące przypomnienia
- Szybki dostęp do głównych funkcji

#### Tankowania (Fuel)
- Dodawanie tankowań (pełny/częściowy bak)
- Śledzenie poziomu paliwa przed i po tankowaniu
- Automatyczne obliczanie spalania:
  - Metoda pełnego baku (dokładna)
  - Metoda szacunkowa z poziomami paliwa
- Historia tankowań z przebiegiem
- Wyświetlanie spalania (L/100km) z oznaczeniem typu pomiaru
- Wsparcie dla różnych typów paliwa

#### Wydatki (Expenses)
- Ewidencja wszystkich wydatków związanych z pojazdem
- Dodaj wydatek — szybkie dodawanie nowych wydatków
- Szczegóły wydatków — analityka z wykresami:
    - Wykres kołowy: rozkład wydatków według kategorii (%)
    - Wykres słupkowy: miesięczne wydatki z filtrem kategorii
- Kalkulator kosztów podróży — planowanie kosztów:
    - Dystans podróży
    - Aktualna cena paliwa
    - Wybór cyklu jazdy (miasto/trasa/mieszany)
    - Automatyczne obliczenie na podstawie historycznego spalania
- Kategoryzacja wydatków (paliwo, serwis, ubezpieczenie, części, inne)

#### Serwis (Services)
- Historia napraw i przeglądów
- Dodawanie usług serwisowych
- Śledzenie kosztów napraw
- Informacje o wykonawcach

#### Przypomnienia (Reminders)
- Tworzenie przypomnień czasowych lub przebiegu
- Przypomnienia o:
  - Przeglądach okresowych
  - Ubezpieczeniu
  - Wymianie opon
  - Wymianie oleju
  - Innych czynnościach
- Podgląd nadchodzących i przeszłych przypomnień

### Technologie i architektura

- **Framework**: Flutter 3.x
- **Język**: Dart
- **Zarządzanie stanem**: StatefulWidget z lokalnym stanem
- **Komunikacja z API**: HTTP client z autoryzacją JWT
- **Wizualizacja danych**: fl_chart (wykresy kołowe i słupkowe)
- **Design**: Material Design 3 z ciemnym motywem
- **Architektura**: Feature-based structure
  - Separacja features (fuel, expenses, services, reminders)
  - Centralne serwisy API
  - Wspólne modele danych
  - Reużywalne komponenty UI

### Konfiguracja aplikacji

Przed uruchomieniem należy skonfigurować adres API w pliku `lib/core/api_client.dart`:

```dart
static const String baseUrl = 'http://localhost:8000'; // lub adres serwera
```

### Uruchomienie aplikacji

```powershell
cd Flutter-App
flutter pub get
flutter run
```