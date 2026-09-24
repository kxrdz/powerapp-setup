# Power Apps Code Apps — Einführung für Entwickler

**Format:** ~30 Minuten Überblick + Q&A
**Publikum:** Entwickler mit React/TypeScript-Erfahrung
**Ziel:** Verstehen, was Code Apps sind, wann man sie einsetzt und wie man in 15 Minuten von Null zur deployten App kommt.

---

## Agenda (Vorschlag mit Zeitbudget)

| # | Thema | Zeit |
|---|-------|------|
| 1 | Warum das Thema — Einordnung | 3 min |
| 2 | Was sind Code Apps | 4 min |
| 3 | Architektur: was die Plattform übernimmt | 5 min |
| 4 | Das Connector-Prinzip (wichtigstes Konzept) | 5 min |
| 5 | Live-Demo: Scaffold → Deploy | 7 min |
| 6 | Grenzen, Lizenzen, Voraussetzungen | 4 min |
| 7 | Wie startet ihr / nächste Schritte | 2 min |
| | Q&A | Rest |

---

## 1. Warum das Thema — Einordnung (3 min)

**Sag das:**

Bisher gab es in der Power Platform zwei Wege:

- **Canvas Apps / Model-driven Apps** — Low-Code, schnell, aber begrenzt bei UI-Freiheit, Testbarkeit, Code-Reviews und Wiederverwendung.
- **Eigene Web-App in Azure** — volle Freiheit, aber ihr baut Auth, Hosting, Secrets-Management, Deployment-Pipeline und Governance selbst.

**Code Apps sind der dritte Weg:** Ihr schreibt eine ganz normale React/Vite-SPA — und die Power Platform übernimmt Authentifizierung, Hosting, Datenzugriff und Governance.

**Kernbotschaft für den Einstieg:**
> "Ihr schreibt React. Die Plattform kümmert sich um Entra-Login, Hosting, 1.500+ Datenquellen und die Compliance-Themen, die euch sonst Wochen kosten."

**Typische Zuhörerfrage vorwegnehmen:** *"Ersetzt das Canvas Apps?"* → Nein. Canvas bleibt richtig für einfache Formular-Apps, die auch Nicht-Entwickler pflegen. Code Apps sind für Fälle, wo ihr echten Code, Tests, Git-Workflow und komplexe UI braucht.

---

## 2. Was sind Code Apps (4 min)

**Sag das:**

Eine Code App ist eine Single-Page-Application (SPA), die in einer Power-Platform-Umgebung gehostet und ausgeführt wird.

- Beliebiges Frontend-Framework: React, Vue, Svelte — alles was zu statischem HTML/JS kompiliert
- Entwicklung lokal in VS Code, ganz normaler Dev-Server
- Deployment per CLI: `pa app push`
- Läuft danach unter `https://apps.powerapps.com/play/e/{env}/a/{app}`

**Was ihr dadurch bekommt, ohne es zu bauen:**

- Microsoft Entra ID Authentifizierung & Autorisierung
- Zugriff auf Power Platform Datenquellen und 1.500+ Connectors — direkt aus JavaScript
- Hosting und Versionierung der App
- Einhaltung der Managed-Platform-Policies: Sharing Limits, Conditional Access, Data Loss Prevention (DLP)
- Vereinfachtes Deployment und ALM (Solutions, Pipelines Dev → Test → Prod)

**Analogie, die gut ankommt:**
> "Wie ein Static Web App Hosting — aber mit eingebautem SSO, einem vorkonfigurierten API-Gateway zu 1.500 Systemen und der Governance, die eure Compliance-Abteilung ohnehin verlangt."

---

## 3. Architektur: was die Plattform übernimmt (5 min)

**Zeichne/zeige diese drei Schichten:**

```
┌─────────────────────────────────────┐
│  Euer Code (React + TypeScript)     │  ← ihr schreibt das
├─────────────────────────────────────┤
│  @microsoft/power-apps (SDK)        │  ← npm-Paket
│  + generierte Models & Services      │  ← CLI generiert das
├─────────────────────────────────────┤
│  Power Apps Host                     │  ← Auth, Hosting, Connector-Proxy
└─────────────────────────────────────┘
```

**Die vier Bausteine, die ihr kennen müsst:**

| Baustein | Was es ist |
|----------|-----------|
| `@microsoft/power-apps` | npm-Paket ("Power Apps SDK"). Stellt APIs bereit und verwaltet Models/Services. |
| `power.config.json` | Metadaten-Datei: Environment-ID, App-ID, registrierte Datenquellen. **Euer App-Code fasst die nie an.** |
| `src/generated/` | Vom CLI generierte TypeScript-Models und -Services pro Connector. Typisiert, nicht manuell editieren. |
| Power Apps CLI (`pa`) | Init, Datenquellen hinzufügen, lokal starten, publishen. |

**Wichtiger Punkt zum Betonen:**
Das CLI generiert aus dem Connector-Schema echte TypeScript-Typen. Ihr bekommt Autocomplete und Compile-Fehler statt Runtime-Überraschungen — das ist der Hauptvorteil gegenüber Canvas.

---

## 4. Das Connector-Prinzip — WICHTIGSTES KONZEPT (5 min)

**Sag das mit Nachdruck — das ist der häufigste Stolperstein:**

> **Code Apps laufen in einer Sandbox. Direkte HTTP-Calls funktionieren zur Laufzeit NICHT.**
> Kein `fetch()` gegen eine fremde API. Kein `axios`. Kein direkter Microsoft-Graph-Call.
> **Jeder externe Datenzugriff läuft über Power Platform Connectors.**

**Warum das so ist (und warum es gut ist):**

- Der Connector-Proxy hält die Credentials — ihr habt **keine Secrets im Frontend-Bundle**
- DLP-Policies greifen automatisch: Admin kann z.B. "SharePoint-Daten dürfen nicht nach Twitter" erzwingen
- Der Nutzer sieht einen Consent-Dialog mit feingranularen Berechtigungen
- Ihr müsst keine Token-Refresh-Logik bauen

**So sieht der Workflow aus:**

```bash
# 1. Verfügbare Connectors suchen
pa connector list --search teams

# 2. Connection anlegen (Browser-Consent)
pa connection create --connector shared_teams

# 3. Als Datenquelle in die App einbinden -> generiert Types
pa app add data-source --connector sharepointonline \
  -c <connection-id> \
  -d 'https://contoso.sharepoint.com/sites/Projects' \
  --table 'Project Milestones'
```

**Und im Code:**

```ts
import { SharePointOnlineService } from '@/generated/services/SharePointOnlineService';

const result = await SharePointOnlineService.GetItems({
  dataset: 'https://contoso.sharepoint.com/sites/Projects',
  table: 'Project Milestones',
});
const milestones = result.data?.value ?? [];
```

**Merksatz für die Folie:**
> Vollständig typisiert. Keine Credentials im Code. Kein Token-Handling.

**Häufige Datenquellen im Team-Kontext:** Dataverse (eigene Business-Tabellen), SharePoint, Teams, Office 365 Outlook, OneDrive, Azure DevOps, Azure SQL, Copilot Studio Agents.

---

## 5. Live-Demo: Scaffold → Deploy (7 min)

**Demo-Skript — vorher einmal durchlaufen, damit Login/Consent schon gecached sind!**

```bash
# Projekt aus dem offiziellen Vite-Template anlegen
npx degit microsoft/PowerAppsCodeApps/templates/vite my-app
cd my-app
npm install

# Als Code App in einer Umgebung registrieren
# (Environment-ID = GUID aus der make.powerapps.com URL)
pa app init --display-name "Meine Demo App" --environment-id <env-id>

# Lokal starten - mit echten Connections gegen die echte Umgebung
pa app run

# Bauen und publishen
npm run build
pa app push
```

**Was ihr dabei zeigen solltet:**

1. `power.config.json` nach `init` öffnen → Environment-ID, App-ID
2. `pa app run` → die App läuft lokal, greift aber auf **echte** Connections zu. Das ist der eigentliche Produktivitätsgewinn: kein Deploy-Zyklus zum Testen.
3. Nach `pa app push` → die App-URL öffnen, zeigen dass der Entra-Login greift
4. In `make.powerapps.com` zeigen, wie man die App teilt

**Hinweis für die Demo — Browser-Falle:**
Chrome und Edge blockieren standardmäßig Requests von öffentlichen Origins auf lokale Endpunkte. Bei `pa app run` ggf. Browser-Permission bestätigen. **Wichtig:** Die lokale URL im selben Browser-Profil öffnen, in dem ihr im Power-Platform-Tenant angemeldet seid.

**Das Template in diesem Repo erwähnen:**
Unser Starter-Template (`powerapp-setup`) bringt bereits mit:
Tailwind CSS, shadcn/ui, React Router, Zustand, TanStack Query, TanStack Table, Lucide Icons, Recharts, Sonner — plus Dark-/Light-Theme.
→ Ihr fangt nicht bei einem weißen `App.tsx` an.

---

## 6. Grenzen, Lizenzen, Voraussetzungen (4 min)

**Das müsst ihr ehrlich ansprechen, sonst gibt es später Frust.**

### Voraussetzungen

| Was | Details |
|-----|---------|
| Node.js | LTS-Version (v22+) |
| Git | empfohlen |
| Power Apps CLI | `npm install --global @microsoft/power-apps-cli` |
| Umgebung | **Code Apps müssen vom Admin aktiviert sein**: Admin Center → Environments → Settings → Product → Features → "Enable code apps" |
| Lizenz Endnutzer | **Power Apps Premium** (oder Pay-as-you-go / App Pass / Auto-Claim) |

> **Die Lizenzfrage kommt garantiert.** Jeder Endnutzer, der die App startet, braucht eine Premium-Lizenz. Das ist ein Kostenfaktor — vorher mit dem Lizenz-Verantwortlichen klären.

### Aktuelle Limitierungen

- **Kein Power Platform Git-Integration-Support** — ihr nutzt euer eigenes Git, das ist ohnehin besser, aber die Solution-Git-Integration greift nicht
- **Keine SAS-IP-Restriction** — die kompilierten Assets liegen auf einem öffentlichen Endpunkt. IP-Einschränkung nur über Conditional Access (Block by Location).
  → **Konsequenz: keine sensiblen Daten ins Bundle hardcoden.** Daten immer über Datenquellen laden, dann greifen Auth + Autorisierung.
- **Keine Secure Implicit Connections** (noch nicht)
- **Nicht unterstützt in Power Apps für Windows**
- **Keine Power BI Datenintegration** (`PowerBIIntegration`) — Einbettung in Power BI Reports über das Power Apps Visual geht aber
- **Keine SharePoint-Forms-Integration**
- **Nicht verfügbar in Dataverse-for-Teams-Umgebungen**
- **Excel Online (Business/OneDrive)** ist über den Standard-CLI-Pfad noch nicht als Datenquelle unterstützt (Workaround existiert)

### Was funktioniert (Governance)

Consent-Dialog, Sharing Limits, App Quarantine, DLP-Enforcement beim App-Start, Conditional Access pro App, Tenant Isolation, Azure B2B für externe Nutzer, Health Metrics im Admin Center.

---

## 7. Wie startet ihr / nächste Schritte (2 min)

**Konkreter Call to Action — nicht mit "Fragen?" enden.**

1. **Umgebung klären:** Wer ist euer Environment-Admin? Ist "Enable code apps" gesetzt? Habt ihr Maker-Rechte?
2. **Tooling installieren:** Node LTS, Git, `npm i -g @microsoft/power-apps-cli`
3. **Erste App bauen:** Template klonen, `pa app init`, `pa app push` — das dauert wirklich 15 Minuten
4. **Erste echte Datenquelle anbinden:** meist Dataverse oder SharePoint
5. **ALM planen, bevor es produktiv geht:** App in eine Solution legen, Power Platform Pipelines für Dev → Test → Prod

**Ressourcen:**

- Offizielle Doku: `learn.microsoft.com/power-apps/developer/code-apps/overview`
- Samples & Templates: `github.com/microsoft/PowerAppsCodeApps`
- CLI-Referenz: `learn.microsoft.com/power-apps/developer/code-apps/reference/cli`
- Unser Starter-Template + Agent-Skills: dieses Repo

---

## Anhang: Die wichtigsten CLI-Befehle (Handout)

```bash
# Auth
pa auth login
pa auth status

# Projekt
pa app init --display-name "App" --environment-id <guid>
pa app run                    # lokal mit echten Connections
pa app push                   # bauen & publishen
pa app list                   # Code Apps der Umgebung
pa app share                  # App teilen

# Connections
pa connector list --search <term>
pa connection create --connector shared_office365
pa connection list

# Datenquellen
pa app add data-source --connector <id> ...
pa app refresh data-source --name <name>
pa app remove data-source --connector <id> --name <name>

# Power Automate Flows einbinden
pa app list-flows
pa app add flow

# App-Settings
pa app get-settings
pa app set-setting --show-header false     # Power Apps Header ausblenden
```

**Kleiner Praxis-Tipp zum Abschluss:**
Den Power-Apps-Header könnt ihr ausblenden — entweder dauerhaft per `pa app set-setting --show-header false` oder pro URL mit `?hideNavBar=true`. Das wollen die meisten für Line-of-Business-Apps.

---

## Anhang: Erwartbare Fragen und Antworten

| Frage | Antwort |
|-------|---------|
| *Kann ich Vue/Svelte/Angular nutzen?* | Ja, alles was zu einer SPA kompiliert. Die offiziellen Templates sind React/Vite. |
| *Kann ich meine bestehende React-App migrieren?* | Meistens ja. Der Aufwand steckt im Ersetzen aller direkten API-Calls durch Connectors. |
| *Wie teste ich lokal?* | `pa app run` — lokaler Dev-Server, aber gegen echte Connections der Umgebung. |
| *Wie funktioniert CI/CD?* | `PA_CLI_SOLUTION_ID=<guid> pa app push` non-interaktiv, mit Service Principal. Danach Power Platform Pipelines. |
| *Kostet das extra?* | Ja — Endnutzer brauchen Power Apps Premium. Vorab klären. |
| *Kann ich Canvas-Komponenten wiederverwenden?* | Nein, andere Welt. Ihr baut React-Komponenten. |
| *Was ist mit Offline?* | Nicht unterstützt. Code Apps brauchen eine Verbindung. |
| *Kann ich Power Automate Flows aufrufen?* | Ja, `pa app add flow` bindet solution-aware Flows typisiert ein. |
