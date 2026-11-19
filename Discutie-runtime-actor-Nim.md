# NVIDIA OpenShell — Analiză pentru MCA Actor Runtime și NACM
**18 noiembrie 2026**

**Verdict Nim: `DESIGN REFERENCE ACCEPTED / SELECTIVE REUSE RECOMMENDED`**

Am analizat arhiva `OpenShell-dev.tar.gz`, inclusiv codul Rust pentru sandbox, procese, Podman, SSH și accesul la modelele AI. Am confruntat implementarea cu documentația oficială NVIDIA și cu arhitectura Human–AI Team.

**Concluzia: OpenShell conține câteva soluții inginerești foarte utile, dar nu recomand importarea întregului runtime.** Ar introduce componente care dublează MCA, MCAD și NACM, fără să ne ofere direct runtime-ul actorului pe care îl dezvoltăm în Nim.

Recomand preluarea selectivă a mecanismelor și scenariilor de test.

## 1. Identitatea surselor analizate

| Proprietate | Valoare |
|---|---|
| Proiect | [NVIDIA/OpenShell](https://github.com/NVIDIA/OpenShell?utm_source=chatgpt.com) |
| Arhivă | `OpenShell-dev.tar.gz` |
| SHA-256 | `0d4f3011e2db32688338dfc5880646135ce878e18a3b242baeff7fdba60b973e` |
| Membri TAR | 2.595 |
| Fișiere obișnuite | 2.092 |
| Limbaj principal | Rust |
| Licență | Apache-2.0 |
| Tip | Snapshot de dezvoltare |

Arhiva conține în metadatele TAR identificatorul Git `4b433e6e3284574866ed0a837a180dbc00ecc800`, dar nu am confirmat independent corespondența sa cu un commit upstream.

Documentația oficială descrie arhitectura OpenShell 0.1.x, cu izolarea workload-ului și controlul operațiilor printr-un supervisor separat. [docs.nvidia.com](https://docs.nvidia.com/openshell/about/architecture?utm_source=chatgpt.com)

**Evaluarea este statică.** Nu am compilat OpenShell și nu am executat teste pe Artix.

---

## 2. Cum funcționează OpenShell

OpenShell este mai amplu decât runtime-ul nostru.

Arhitectura sa cuprinde:

| Componentă | Responsabilitate |
|---|---|
| Gateway | Administrarea sandboxurilor, identităților, politicilor și serviciilor |
| Supervisor | Deciziile de securitate, accesul la credențiale și comunicațiile externe |
| Sandbox | Mediul izolat și administrarea proceselor agentului |
| Compute Driver | Integrarea cu Podman, Docker, Kubernetes sau VM |
| Policy Prover | Verificarea modificărilor politicilor |
| Provider subsystem | Accesul controlat la API-uri și modele AI |

Implementarea Podman din arhivă creează două containere distincte: unul pentru workload și unul pentru supervisor.

Workload-ul nu are acces direct la rețea; comunicația externă trece prin supervisor, care aplică politica. [GitHub](https://github.com/NVIDIA/OpenShell/blob/main/docs/about/architecture.mdx?utm_source=chatgpt.com)

### Diferența fundamentală față de MCA

În OpenShell, procesul `openshell-sandbox` gestionează workload-ul și lansează agentul ca proces copil.

În arhitectura noastră:

**Actor Runtime este el însuși PID 1 al containerului.**

Această diferență este esențială.

Nu putem introduce `openshell-sandbox` fără să modificăm contractul deja stabilit pentru actor.

---

# 3. Ce merită preluat

Am identificat cinci direcții relevante.

## A. Gestionarea proceselor copil și PID 1 — prioritatea principală

**Sursă examinată:**

`crates/openshell-sandbox/src/managed_children.rs`

Aceasta este una dintre cele mai interesante componente pentru runtime-ul Nim.

OpenShell implementează:

- Recepționarea evenimentelor `SIGCHLD`.
- Colectarea proceselor copil terminate.
- Distincția dintre copiii gestionați explicit și procesele orfane adoptate.
- Protecție împotriva reutilizării identificatorilor PID.
- Verificarea curselor dintre lansarea unui copil și înregistrarea lui.

Există inclusiv teste pentru procese care se termină înainte să fie înregistrate complet.

### Aplicabilitate în MCA

Runtime-ul nostru R2 a demonstrat deja lansarea și oprirea unui proces copil.

Dar există o diferență între:

**A colecta un proces lansat direct de runtime** și **a colecta toate procesele orfane de care PID 1 devine responsabil**.

De exemplu:

```text
Actor Runtime — PID 1
        |
        +── Shell
              |
              +── Script
                    |
                    +── Proces copil
```

Dacă shell-ul sau scriptul se termină înaintea descendenților săi, aceștia pot ajunge în responsabilitatea procesului PID 1.

**Recomandarea mea:** verificăm dacă mecanismul Nim existent gestionează corect această situație.

Dacă nu, îl completăm minimal folosind mecanisme Linux precum `SIGCHLD` și `waitpid()`.

Nu este necesar să portăm în Nim întregul registru concurent din Rust.

**Prioritate: RIDICATĂ — aplicabil direct în următoarea etapă a runtime-ului.**

---

## B. Identitatea Unix și home-ul persistent — pentru Worf

**Surse examinate:**

`crates/openshell-driver-podman/src/isolation.rs`

`crates/openshell-driver-podman/src/container.rs`

`crates/openshell-driver-podman/README.md`

OpenShell acordă atenție unor detalii relevante pentru NACM:

- Identitatea UID/GID finală a workload-ului.
- Maparea user namespace-urilor.
- Proprietarul volumelor persistente.
- Verificarea configurației Podman înaintea pornirii.
- Separarea volumelor persistente de filesystem-ul containerului.
- Curățarea exclusivă a resurselor deținute de manager.

O constatare utilă din documentația sursă: un director din filesystem-ul containerului poate supraviețui unui simplu stop/start, dar poate dispărea când containerul este distrus și recreat.

Pentru actorii noștri acest lucru este important.

**Home-ul actorului trebuie să supraviețuiască inclusiv recreării containerului**, nu numai repornirii procesului.

Recomand folosirea unui volum persistent explicit, configurat de NACM, cu UID/GID și permisiuni verificate practic.

Nu importăm driverul Podman OpenShell. Worf reutilizează direct Podman/crun.

**Prioritate: RIDICATĂ — responsabilitate NACM.**

---

## C. Accesul la modele fără expunerea credențialelor

**Surse examinate:**

`docs/how-it-works/inference.mdx`

`crates/openshell-supervisor-network/`

OpenShell folosește o separare interesantă:

Agentul poate solicita acces la un provider, dar credențialele reale sunt administrate în afara workload-ului și folosite numai pentru destinațiile aprobate.

Această soluție confirmă o decizie deja stabilită pentru MCA:

**Actorul solicită modelul; MCAD verifică autorizarea și administrează accesul la provider.**

În arhitectura noastră, MCAD trebuie să gestioneze și consumul și costurile.

Nu recomand importarea proxy-ului OpenShell.

Avem nevoie de funcționalitatea specifică MCA:

```text
Actor Runtime
      |
      | Solicită modelul X
      v
MCAD
      |
      +── Identitate actor
      +── Passport
      +── Model aprobat?
      +── Limită de utilizare
      +── Buget disponibil
      |
      v
Provider AI
```

Acest serviciu trebuie implementat în MCAD, folosind mecanismele deja dezvoltate pentru gateway-ul AI.

**Prioritate: MEDIE — pentru etapa de materializare a instanței AI.**

---

## D. Verificarea stării reale, nu doar a configurației

OpenShell distinge între existența unui container, aplicarea izolării și disponibilitatea efectivă a serviciului.

Ideea este relevantă și pentru noi.

Runtime-ul actorului nu trebuie să declare că instanța AI este funcțională doar pentru că procesul PID 1 există.

Propun să distingem următoarele informații operaționale:

| Proprietate | Semnificație |
|---|---|
| Proces activ | Runtime-ul funcționează |
| Context disponibil | Repository-urile necesare sunt accesibile |
| Identitate SSH verificată | Comunicarea autorizată este posibilă |
| Model AI disponibil | MCAD poate furniza inferență |
| Actor disponibil | Actorul poate primi și procesa sarcini |

Nu propun un sistem complex de stări.

Sunt suficiente verificări explicite, în locul unui `READY` care poate ascunde funcționalități indisponibile.

**Prioritate: MEDIE.**

---

## E. Testele de lifecycle și recuperare

OpenShell include teste pentru:

- procese copil care se termină foarte repede;
- întreruperi în timpul lansării;
- deconectări;
- restart;
- păstrarea sau pierderea resurselor;
- curățarea proceselor și descriptorilor;
- refuzul operațiilor când frontiera nu este disponibilă.

Merită să adaptăm **scenariile de test**, nu infrastructura lor.

În special pentru actorii noștri:

1. Pornire.
2. Execuție Git și VFS.
3. Lansare procese copil.
4. SIGTERM.
5. Repornire.
6. Recuperare context.
7. Verificarea proceselor orfane.
8. Verificarea disponibilității serviciilor MCA.

**Prioritate: RIDICATĂ pentru PID 1, ulterior pentru integrarea SSH/MCAD.**

---

# 4. Ce NU recomand să importăm

| Componentă OpenShell | Decizie | Motiv |
|---|---|---|
| Gateway | **NU** | Duplică MCA/MCAD |
| Supervisor | **NU** | Introduce un al doilea control plane |
| Sandbox ca PID 1 | **NU** | Contrazice contractul runtime-ului actorului |
| Driver Podman complet | **NU** | Duplică NACM |
| Protocol gRPC/JWT intern | **NU** | Avem OpenSSH și protocolul echipei |
| Policy Prover | **NU, acum** | Complexitate nejustificată pentru prima integrare |
| Proxy de credențiale | **NU** | Funcționalitatea aparține MCAD |
| Sistem propriu de context | **NU** | Avem Git, Forgejo, CMS și KAM |

Există și o diferență de securitate de reținut: OpenShell poate aplica politici mai granulare asupra acceselor la fișiere, proceselor și rețelei decât configurația Linux-native stabilită momentan pentru NACM.

**Nu trebuie să pretindem că cele două soluții oferă garanții identice.**

Pentru modelul nostru, Worf trebuie să valideze protecțiile Linux configurate efectiv.

---

# 5. Impactul asupra dezvoltării Actor Runtime

Nu propun modificarea planului R1–R4.

Avem deja:

| Etapă | Rezultat |
|---|---|
| R1 — Fundație proces | ARTIX PASS |
| R2 — Shell, procese copil, Git/VFS | ARTIX PASS |
| R3 — Context personal/public/proiect | ARTIX PASS |
| R4/P1 — Primitive OpenSSH | ARTIX PASS |
| R4/P2 — SSH real și Git remote | ARTIX PENDING |

**R4/P2 trebuie continuat folosind pachetul deja pregătit.**

În paralel, analiza OpenShell evidențiază o verificare suplimentară importantă pentru procesul care va deveni PID 1.

### Propunere Nim — PID1-C1

Nu o transformăm într-un nou subsistem.

Este o verificare focalizată a sursei runtime-ului existent:

**Poate runtime-ul să colecteze corect procesele orfane adoptate după terminarea proceselor copil?**

Dacă răspunsul este da, păstrăm implementarea.

Dacă identificăm o lipsă, facem cea mai mică modificare necesară și o verificăm pe Artix.

Testul real ca PID 1 rămâne dependent de autorizarea NACM.

---

# 6. Ce putem transmite lui Worf

Din analiza OpenShell rezultă câteva recomandări concrete pentru NACM:

**Identitatea:** verificarea UID/GID efectiv, nu numai a configurației Podman.

**Persistența:** home-ul actorului trebuie să fie independent de durata de viață a containerului.

**Montările:** verificarea că actorul nu primește accidental acces la directoarele administrative ale hostului.

**Lifecycle:** verificarea stării reale a containerului și a resurselor sale.

**Rețeaua:** păstrarea izolării aprobate, fără presupunerea că simpla configurare `network=none` demonstrează întregul contract de securitate.

Acestea sunt idei de verificare pentru Worf, nu propuneri de a înlocui NACM cu OpenShell.

---

## 7. Raportul tehnic

Am pregătit o notă reutilizabilă pentru proiect, cu referințe la fișierele exacte din arhivă și deciziile recomandate.

**:chatgpt-content-reference{index="4"}[Descarcă analiza OpenShell → MCA/NACM](sandbox:/mnt/data/openshell-analysis/OPEN-SHELL-TO-MCA-NACM-REVIEW-2026-11-18.md)**

Raportul poate fi transmis și lui Worf pentru completarea verificărilor NACM.

---

## 8. Dispoziția Nim

```text
PROJECT=MCA_ACTOR_RUNTIME
REFERENCE=NVIDIA_OPENSHELL

SOURCE_ARCHIVE=INSPECTED
UPSTREAM_DOCUMENTATION=REVIEWED
STATIC_SOURCE_ANALYSIS=COMPLETE
ARTIX_OPEN_SHELL_TEST=NOT_EXECUTED

DECISION=SELECTIVE_DESIGN_REUSE

ADOPT:
  PID1_ORPHAN_REAPING_TEST_CASES=YES
  CHILD_PROCESS_LIFECYCLE_IDEAS=YES
  PERSISTENT_WORKSPACE_CHECKS=YES
  PODMAN_IDENTITY_READBACK_IDEAS=YES
  PROVIDER_CREDENTIAL_SEPARATION=YES
  READINESS_VERIFICATION_IDEAS=YES

DO_NOT_IMPORT:
  OPENSHELL_GATEWAY=YES
  OPENSHELL_SUPERVISOR=YES
  OPENSHELL_SANDBOX_AS_PID1=YES
  OPENSHELL_CONTAINER_DRIVER=YES
  OPENSHELL_PROTOCOL_STACK=YES

NEXT_RUNTIME:
  R4_P2_REAL_SSH_GIT=ARTIX_PENDING
  PID1_CHILD_REAPING_REVIEW=RECOMMENDED

OFFICIAL_MCA_MUTATION=NONE
NACM_CONTAINER_LAUNCH=NO_GO
PRODUCTION=NO_GO
```

### Concluzie

**OpenShell este o referință inginerească valoroasă, în special pentru lifecycle-ul proceselor Linux și administrarea corectă a frontierelor containerului.**

Dar proiectul nostru are deja o separare clară:

- MCA administrează echipa.
- MCAD oferă serviciile autorizate.
- NACM configurează containerul.
- Runtime-ul Nim materializează actorul ca PID 1.
- Git și VFS îi oferă mediul de lucru.
- CMS/KAM îi oferă cunoașterea.
- Sam coordonează comunicarea.

Nu avem motive să înlocuim această arhitectură.

**Recomand să preluăm imediat lecțiile OpenShell despre PID 1 și procesele orfane, iar restul să rămână referințe pentru NACM și MCAD.**

---------------------->

Worf --->
# Worf Security Watch — NVIDIA OpenShell
## Audit independent pentru MCA Actor Runtime și NACM

**18 noiembrie 2026**

**Verdict: ACCEPT — SELECTIVE DESIGN REUSE / NO RUNTIME ADOPTION**

Am verificat arhiva `OpenShell-dev.tar.gz`, principalele componente indicate de Nim și documentația oficială NVIDIA.

**Sunt de acord cu verdictul lui Nim.** OpenShell oferă mecanisme și scenarii de test valoroase, dar adoptarea infrastructurii sale ar dubla responsabilitățile MCA, MCAD și NACM.

Am identificat și două precizări importante pentru implementarea noastră: una privind responsabilitățile PID 1, cealaltă privind persistența home-ului actorului.

## 1. Verificarea independentă a arhivei

| Proprietate | Rezultat |
|---|---|
| Arhivă | `OpenShell-dev.tar.gz` |
| SHA-256 | `0d4f3011e2db32688338dfc5880646135ce878e18a3b242baeff7fdba60b973e` |
| Intrări TAR | 2.595 |
| Fișiere obișnuite | 2.092 |
| Directoare | 502 |
| Legături | 1 |
| Căi nesigure identificate | 0 |
| Marcaj Git PAX | `4b433e6e3284574866ed0a837a180dbc00ecc800` |
| Consistență PAX | 2.595/2.595 |
| Compilare | Neexecutată |
| Runtime | Neexecutat |

**Integritatea structurală și identitatea arhivei sunt confirmate.** Nu am verificat independent asocierea marcajului Git cu un commit public upstream.

Documentația NVIDIA confirmă separarea dintre sandbox, supervisor și gateway, precum și utilizarea unor drivere OCI, inclusiv Podman. [docs.nvidia.com](https://docs.nvidia.com/openshell/about/architecture?utm_source=chatgpt.com)

## 2. PID 1 — cea mai importantă lecție pentru Nim

Am examinat:

`crates/openshell-sandbox/src/managed_children.rs`

Implementarea conține mecanisme concrete pentru:

- Tratarea `SIGCHLD`.
- Colectarea proceselor orfane adoptate.
- Separarea copiilor gestionați explicit de cei neînregistrați.
- Protecția împotriva reutilizării PID-urilor.
- Evitarea cursei dintre `spawn()` și înregistrarea procesului.
- Utilizarea `waitid(..., WNOWAIT)` pentru observarea terminării fără colectare prematură.
- Un mecanism de notificare bazat pe `eventfd`.

Acestea sunt verificări relevante pentru runtime-ul Nim care va ocupa PID 1.

**Recomandarea Worf: ACCEPT PID1-C1 ca audit focalizat.**

Înainte de a modifica sursa Nim, trebuie verificat ce gestionează deja runtime-ul.

Dacă există o lipsă, implementăm strict mecanismul necesar, reutilizând apelurile Linux.

Nu recomand portarea registrului concurent Rust.

O distincție importantă: **PID 1 nu trebuie să colecteze prematur procese pentru care alte componente așteaptă explicit rezultatul execuției.** Acesta este motivul pentru care implementarea OpenShell diferențiază copiii gestionați de cei orfani.

## 3. NACM — identitatea Unix

Am examinat:

`crates/openshell-driver-podman/src/isolation.rs`

Codul rezolvă identitatea workloadului din configurația aprobată și informațiile conturilor din imaginea OCI.

Este relevant faptul că OpenShell nu presupune că UID-ul declarat în configurație este suficient pentru demonstrarea identității efective.

Pentru NACM păstrăm trei verificări:

| Nivel | Ce verificăm |
|---|---|
| Configurație OCI | UID/GID solicitate |
| User namespace | Maparea UID/GID container–host |
| Proces activ | UID/GID efective observate de kernel |

Nu avem nevoie de implementarea Rust.

Podman și instrumentele Linux existente sunt suficiente.

**Decizie: `NACM_UID_GID_READBACK=REQUIRED`.**

## 4. NACM — home persistent

Aceasta este a doua recomandare importantă.

OpenShell separă explicit volumele persistente de filesystemul containerului. Documentația driverului Podman descrie crearea volumelor cu proprietarul corespunzător identității finale a workloadului. [GitHub](https://github.com/NVIDIA/OpenShell/blob/main/docs/how-it-works/sandboxes/runtimes.mdx?utm_source=chatgpt.com)

Pentru actorii noștri, contractul trebuie formulat astfel:

**Home-ul actorului aparține identității sale persistente, nu instanței containerului.**

Consecințele sunt clare:

- Oprirea containerului nu șterge home-ul.
- Repornirea containerului păstrează home-ul.
- Recrearea containerului utilizează același home autorizat.
- Actualizarea imaginii Artix nu distruge datele actorului.
- UID/GID și permisiunile volumului trebuie să rămână corecte.

Recomand un volum persistent Podman explicit pentru fiecare actor.

Nu recomand montarea home-ului utilizatorului Human.

**Decizie: `NACM_ACTOR_HOME=PERSISTENT_VOLUME`.**

Aceasta este o cerință pentru configurația viitoare a actorului, nu o afirmație despre implementarea actuală NACM.

## 5. O observație importantă despre OpenShell și rețea

OpenShell utilizează două containere distincte pentru workload și supervisor.

Workloadul poate rămâne fără conectivitate directă, în timp ce supervisorul gestionează comunicațiile externe aprobate.

Acest model este confirmat și în README-ul driverului Podman. [docs.nvidia.com](https://docs.nvidia.com/openshell/about/architecture?utm_source=chatgpt.com)

Pentru Human–AI Team **nu recomand preluarea acestui model**.

Actorii noștri trebuie să utilizeze SSH, Git/Forgejo și serviciile aprobate. Accesul la modele AI trece prin MCAD, dar nu trebuie să construim un proxy generic care interceptează toate comunicațiile.

Păstrăm mecanismele normale Linux de conectivitate și drepturile acordate de serviciile accesate.

Este însă important să nu pretindem că izolarea NACM și cea OpenShell sunt echivalente: OpenShell utilizează controale suplimentare, inclusiv medierea comunicațiilor și mecanisme de aplicare a politicilor la runtime.

## 6. Ce propun concret pentru fiecare proiect

| Componentă | Recomandare Worf | Prioritate |
|---|---|---|
| Nim Runtime | Audit PID 1, `SIGCHLD`, orfani și procese copil | Ridicată |
| NACM | UID/GID efective și mapări user namespace | Ridicată |
| NACM | Home persistent independent de container | Ridicată |
| NACM | Verificarea mounturilor efective | Ridicată |
| NACM | Verificarea limitelor cgroups | Ridicată |
| MCAD | Păstrarea credențialelor providerilor în afara containerului | Deja stabilită |
| Nim Runtime | Verificări explicite ale disponibilității serviciilor | Medie |
| MCA/NACM | Import OpenShell Supervisor/Gateway | **NU** |

### Ordinea de lucru recomandată

Pentru NACM nu schimbăm planul deja stabilit.

**Mai întâi finalizăm R1/P7-A4/P7**, adică prima pornire OCI prin Podman/crun din cgroupul delegat.

Această probă a fost pregătită, dar nu avem încă rezultatul ei Artix.

După aceea, verificăm identitatea Unix, limitele kernel și home-ul persistent.

În paralel, Nim poate efectua auditul static PID1-C1, fără să aștepte lansarea containerului. Testul efectiv ca PID 1 va necesita ulterior un container autorizat.

---

## 7. Dispoziția oficială Worf

```text
HUMAN_AI_TEAM / WORF_SECURITY

DATE=2026-11-18
PROJECT=NVIDIA_OPENSHELL_REVIEW

SOURCE:
  ARCHIVE=OpenShell-dev.tar.gz
  SHA256=0d4f3011e2db32688338dfc5880646135ce878e18a3b242baeff7fdba60b973e
  TAR_ENTRIES=2595
  PAX_CONSISTENCY=2595/2595
  STATIC_REVIEW=PASS
  BUILD=NOT_PERFORMED
  RUNTIME=NOT_PERFORMED

DECISION=ACCEPT_SELECTIVE_DESIGN_REUSE

MCA_RUNTIME:
  PID1_ORPHAN_REAPING_REVIEW=RECOMMENDED
  CHILD_LIFECYCLE_TESTS=RECOMMENDED
  OPENSHELL_RUNTIME_IMPORT=NO

NACM:
  OCI_ENGINE=PODMAN_CRUN
  UID_GID_READBACK=REQUIRED
  USER_NAMESPACE_MAPPING=REQUIRED
  PERSISTENT_ACTOR_HOME=REQUIRED
  MOUNT_VERIFICATION=REQUIRED
  CGROUP_ENFORCEMENT=NOT_YET_PROVEN

MCAD:
  PROVIDER_CREDENTIAL_ISOLATION=KEEP
  OPENSHELL_GATEWAY_IMPORT=NO
  OPENSHELL_SUPERVISOR_IMPORT=NO

NEXT_NACM=R1_P7_A4_P7_RUNTIME_START
NEXT_NIM=PID1_C1_STATIC_REVIEW

ACTOR_CONTAINER_LAUNCH=NO_GO
PRODUCTION=NO_GO
```

## Concluzia Worf

**OpenShell confirmă utilitatea direcției noastre și evidențiază câteva probleme Linux pe care trebuie să le verificăm practic.**

Cele mai valoroase sunt gestionarea corectă a proceselor copil de către PID 1, identitatea Unix efectivă și persistența datelor independent de container.

Nu văd un motiv pentru introducerea infrastructurii OpenShell în Human–AI Team.

Aș transmite lui Nim acceptarea auditului **PID1-C1**, iar pentru NACM aș păstra prioritățile deja stabilite.

**Recomand continuarea cu rezultatul Artix pentru NACM-R1/P7-A4/P7, fără modificări arhitecturale suplimentare.**

Worf --->
# Worf Security — NVIDIA OpenShell
## Recepția raportului tehnic MCA/NACM

**18 noiembrie 2026**

Am primit documentul `OPEN-SHELL-TO-MCA-NACM-REVIEW-2026-11-18.md`.

Raportul este în concordanță cu evaluarea Worf anterioară și confirmă recomandarea de **reutilizare selectivă a ideilor și scenariilor de test**, fără integrarea componentelor OpenShell. OPEN-SHELL-TO-MCA-NACM-REVIEW-2…

Pentru NACM, păstrăm trei cerințe prioritare: verificarea identității UID/GID efective și a mapărilor, persistența home-ului independent de container și verificarea montărilor și a stării runtime.

Pentru Nim, recomandarea rămâne auditul focalizat al gestionării proceselor copil și a proceselor orfane atunci când runtime-ul funcționează ca PID 1.

**Dispoziția Worf rămâne neschimbată:**

```text
OPENSHELL=DESIGN_REFERENCE_ACCEPTED
SOURCE_CODE_IMPORT=NO

NACM_RUNTIME=PODMAN_CRUN
NACM_NEXT=R1_P7_A4_P7_RUNTIME_START

NIM_RUNTIME=PID1
NIM_NEXT=PID1_CHILD_REAPING_REVIEW

ACTOR_CONTAINER_LAUNCH=NO_GO
PRODUCTION=NO_GO
```

Următorul pas NACM este executarea probei R1/P7-A4/P7 deja pregătite, exclusiv cu `/usr/bin/true`, fără actor AI.

------------------>

Bine, super. Acum hai sa lasam putin deoparte totul si sa discutam mai in detaliu despre acest runtime. Mai intii ma gindesc sa comparam OpenShell cu mcad + runtime actor. Ce este echivalent/apropiat si ce diferea. Si apoi sa discutam pe sub-sisteme. Ideea este ca trebuie sa definim mai exact functiile pe care trebuie sa le ofere mcad + runtime.

Nim --->
# MCA / MCAD / Actor Runtime versus NVIDIA OpenShell
## Analiză arhitecturală și definirea subsistemelor
**18 noiembrie 2026 — Discuție de arhitectură**

Propun să suspendăm temporar implementarea R5 și să revenim la o întrebare fundamentală:

**Ce servicii trebuie să ofere MCAD și ce funcții trebuie să îndeplinească runtime-ul pentru ca un actor AI să poată exista, lucra autonom, acumula experiență și colabora cu ceilalți membri ai echipei?**

Comparația cu NVIDIA OpenShell este utilă tocmai pentru că proiectele rezolvă probleme parțial comune, dar urmăresc obiective diferite.

Am reluat arhiva OpenShell furnizată și documentația NVIDIA. Distincția importantă este următoarea:

- **OpenShell** este în principal o infrastructură de execuție și izolare pentru agenți AI, cu politici de securitate aplicate asupra operațiilor.
- **MCA + MCAD + Actor Runtime** urmărește construirea unei echipe persistente de actori AI, fiecare având identitate, rol, instrumente, context, experiență și relații de colaborare.

Prima arhitectură este centrată pe **mediul controlat în care rulează agentul**.

A doua trebuie să fie centrată atât pe **mediul de lucru**, cât și pe **funcționarea efectivă a actorului AI**.

Această diferență ne va ajuta să stabilim ce trebuie implementat.

---

# 1. Comparația componentelor principale

## 1.1. Harta de corespondență

| NVIDIA OpenShell | MCA / Human–AI Team | Grad de echivalență |
|---|---|---|
| Gateway — managementul sandboxurilor | MCA + MCAD + NACM | Parțial; responsabilitățile sunt împărțite |
| Gateway — configurare și autorizare | MCA | Apropiat, dar MCA administrează și echipa |
| Gateway — servicii operaționale | MCAD | Apropiat |
| Compute Driver | NACM + Podman/crun | Apropiat |
| Sandbox Runtime | Actor Runtime | Parțial |
| Supervisor | MCAD + controalele NACM/Linux | Numai unele funcții |
| Policy Engine | MCA Passport + NACM/Linux | Modele de autorizare diferite |
| Provider Management | MCAD — Model Services | Apropiat |
| Agent Workload | Instanța AI a actorului | Conceptual apropiat |
| Workspace | Home persistent + VFS + Git | Parțial |
| Sandbox Authentication | MCA + OpenSSH + MCAD | Scop apropiat, mecanism diferit |
| Logs / Telemetry | MCAD + jurnale Linux | Parțial |
| — | CMS / Jordy | Nu are echivalent direct |
| — | KAM / Spok | Nu are echivalent direct |
| — | Sam / Team Mailbox | Nu are echivalent organizațional direct |
| — | Experiența și personalitatea actorului | Nu sunt funcții centrale OpenShell |

Un lucru trebuie clarificat: **nu există o corespondență unu-la-unu între componente**.

De exemplu, Gateway-ul OpenShell combină funcții pe care noi le-am repartizat între trei componente: MCA, MCAD și NACM.

Iar Supervisor-ul OpenShell nu este echivalent cu MCAD. Supervisor-ul mediază efectiv accesul workload-ului la rețea, credențiale și alte operații, în timp ce MCAD este proiectat ca furnizor al unor servicii autorizate, nu ca intermediar obligatoriu pentru fiecare operație Linux.

Documentația NVIDIA confirmă aceste responsabilități, inclusiv existența unui supervisor de încredere separat de workload. [NVIDIA Docs](https://docs.nvidia.com/openshell/about/architecture?utm_source=chatgpt.com)

---

# 2. Diferența fundamentală: sandbox versus actor

În OpenShell, arhitectura poate fi simplificată astfel:

```text
                  OPENSHELL
                     |
                  Gateway
                     |
              Compute Driver
                     |
          +----------+----------+
          |                     |
      Supervisor             Sandbox
       trusted               workload
          |                     |
          |                Agent Process
          |
     Policies
     Credentials
     Network Access
     Provider Access
```

Agentul este procesul de lucru lansat și gestionat în sandbox. Sandbox-ul deține procesele agentului și oferă funcții de execuție, terminal, semnale și monitorizare.

În cazul nostru:

```text
                  HUMAN
                    |
                   MCA
                    |
          +---------+---------+
          |                   |
         MCAD                NACM
          |                   |
          |              Podman / crun
          |                   |
          |             Container Artix
          |                   |
          |             Actor Runtime
          |                 PID 1
          |                   |
          +---- SSH ----------+
                              |
                        Instanța AI
                              |
                +-------------+-------------+
                |             |             |
              Shell          Git          Mailbox
                |             |             |
               VFS        Context       Sam / Team
```

Această reprezentare evidențiază două diferențe.

**Prima:** actorul nostru este persistent din punct de vedere al identității și contextului, chiar dacă procesul sau containerul sunt reconstruite.

**A doua:** runtime-ul nu trebuie doar să lanseze un agent. El trebuie să ofere funcțiile necesare pentru ca instanța AI să poată lucra în mediul Linux și să-și continue activitatea.

Aici este zona pe care trebuie să o definim mult mai precis.

---

# 3. Ce putem învăța din OpenShell

Există patru principii pe care consider că merită să le adoptăm.

### A. Separarea autorității de execuție

În OpenShell, workload-ul nu își acordă singur drepturi suplimentare. Componentele din afara frontierei sandboxului controlează operațiile privilegiate.

La noi, principiul se exprimă diferit:

- MCA stabilește autoritatea.
- MCAD verifică autoritatea pentru serviciile sale.
- NACM configurează limitele containerului.
- Linux aplică drepturile efective.
- Actor Runtime lucrează în limitele primite.

Runtime-ul nu trebuie să își poată modifica singur Passport-ul sau identitatea administrativă.

### B. Credibilitatea stării operaționale

Un proces activ nu înseamnă obligatoriu un actor funcțional.

Trebuie să distingem între:

- runtime pornit;
- context disponibil;
- identitate verificată;
- acces la model disponibil;
- actor capabil să execute o sarcină.

Această distincție este mai utilă decât un singur indicator global `READY`.

### C. Separarea credențialelor

Credențialele providerilor AI trebuie să rămână la MCAD.

Actorul nu are nevoie de cheia API a providerului pentru a solicita inferență.

În schimb, actorul are nevoie de propria identitate SSH și de credențialele Git aprobate, fiindcă acestea fac parte din mediul său de lucru.

### D. Tratarea corectă a lifecycle-ului

Runtime-ul trebuie să gestioneze procesele copil, semnalele, oprirea și recuperarea contextului.

OpenShell oferă exemple utile, dar nu este necesar să îi preluăm supervisor-ul.

---

# 4. Inventarul subsistemelor MCAD + Actor Runtime

Aici începe partea importantă a discuției.

Propun să definim sistemul pornind de la **funcțiile necesare actorului**, nu de la numărul modulelor software.

Un subsistem din această analiză reprezintă o responsabilitate logică. Nu înseamnă obligatoriu un executabil, un serviciu sau un modul Nim separat.

## 4.1. Subsistemele MCAD

MCAD este serviciul central care deservește actorii și aplică autoritatea stabilită prin MCA.

Propun următoarea împărțire:

| Subsistem logic | Funcții principale | Autoritatea |
|---|---|---|
| **Identity Service** | Autentifică actorul, asociază cheia SSH cu identitatea MCA, verifică revocarea | MCA |
| **Authorization Service** | Verifică Passport, roluri, drepturi și servicii aprobate | MCA |
| **Model Service** | Oferă acces la modelele AI autorizate | MCA + MCAD |
| **Provider Service** | Administrează conexiunile și credențialele providerilor | MCAD |
| **Usage Accounting** | Înregistrează consumul, costurile și limitele | MCAD |
| **Actor Service Interface** | Primește cereri și returnează răspunsuri către runtime-uri | MCAD |
| **Operational Registry** | Păstrează evidențe operaționale despre actorii conectați și serviciile furnizate | MCAD |

Acestea pot fi implementate în același daemon.

### Ce nu ar trebui să facă MCAD

MCAD nu trebuie să:

- editeze profilurile și Passport-urile actorilor;
- administreze direct repository-urile personale;
- execute comenzile Linux obișnuite ale actorului;
- înlocuiască Podman/NACM;
- gestioneze personalitatea și experiența actorului;
- devină un broker obligatoriu pentru comunicația organizațională Sam.

Există însă o precizare importantă.

**MCAD trebuie să autorizeze serviciile pe care le furnizează, nu să autorizeze întreaga activitate a actorului.**

De exemplu, dacă actorul rulează `git status`, MCAD nu participă.

Dacă solicită utilizarea modelului GPT-6, MCAD verifică identitatea, Passport-ul, modelul aprobat și limitele de utilizare.

Aceasta este o frontieră arhitecturală clară.

---

# 5. Subsistemele Actor Runtime

Aici avem mai mult de definit.

În opinia mea, runtime-ul trebuie analizat din două perspective:

1. **Motorul operațional Linux** — permite actorului să lucreze.
2. **Motorul cognitiv** — permite instanței AI să primească sarcini, să raționeze, să utilizeze instrumente și să păstreze continuitatea.

R1–R4 au validat în principal fundația primei categorii.

A doua categorie este încă în mare parte nedefinită.

## 5.1. Identitatea actorului

Runtime-ul trebuie să cunoască identitatea actorului pentru care a fost pornit.

Propun ca această identitate să cuprindă:

| Element | Semnificație |
|---|---|
| Actor ID | Identitatea logică MCA, de exemplu `ai:nim` |
| Actor Profile | Rol, responsabilități, configurație aprobată |
| Passport | Autoritatea și serviciile aprobate |
| Unix Identity | UID/GID efectiv în container |
| SSH Identity | Identitatea criptografică pentru servicii |
| Home | Spațiul persistent al actorului |

**Principiu:** runtime-ul nu își stabilește singur identitatea administrativă. El pornește cu o identitate configurată și o folosește pentru autentificarea către MCAD.

Trebuie totuși diferențiate configurația locală și identitatea verificată.

Eticheta `ai:nim`, testată în R3, nu este suficientă pentru autorizarea serviciilor MCAD.

---

## 5.2. Inițializarea și lifecycle-ul

Acesta este subsistemul cel mai apropiat de runtime-ul OpenShell.

Funcțiile necesare sunt:

- pornirea ca PID 1;
- inițializarea mediului actorului;
- verificarea home-ului și a contextului;
- lansarea și colectarea proceselor copil;
- gestionarea semnalelor;
- oprirea controlată;
- recuperarea lucrului persistent după repornire.

Propun să nu introducem încă un manager de lifecycle sofisticat.

Ar putea fi suficiente trei stări principale:

```text
STARTING
   |
   v
RUNNING
   |
   v
STOPPING
```

Disponibilitatea Git, SSH, MCAD și a modelului AI poate fi reprezentată separat, prin indicatori de capacitate.

Astfel, `RUNNING` nu trebuie să însemne automat că actorul poate executa inferență AI.

---

## 5.3. Motorul de execuție Linux

Acest subsistem oferă instanței AI acces la mediul de lucru.

Funcțiile principale:

| Funcție | Mecanism |
|---|---|
| Lansare comandă | `fork`/`exec`, shell sau bibliotecile Nim |
| Procese copil | Linux PID, semnale, `waitpid` |
| Terminal interactiv | PTY |
| Fișiere și directoare | Linux VFS |
| Git | Executabil Git existent |
| Aplicații auxiliare | Procese Linux obișnuite |
| Servicii actor | Opțional dinit în user mode |

**Nu propun un sistem propriu de autorizare pentru fiecare comandă.**

Aceasta este o diferență deliberată față de OpenShell.

Runtime-ul poate oferi interfețe convenabile instanței AI, dar Linux și NACM aplică limitele efective.

---

## 5.4. Motorul de context și continuitate

Aici proiectul nostru depășește scopul principal al OpenShell.

Actorul trebuie să își poată recupera contextul de lucru după oprire.

Propun următoarea structură logică:

```text
Actor Home
    |
    +-- Configurație locală
    |
    +-- Context personal Git
    |      |
    |      +-- Personalitate
    |      +-- Experiență
    |      +-- Context curent
    |
    +-- Context public Git
    |
    +-- Context proiect Git
    |
    +-- Workspace
    |      |
    |      +-- Fișiere de lucru
    |      +-- Artefacte
    |
    +-- Identitate SSH persistentă
```

Aceasta este o propunere de organizare logică, nu o structură obligatorie de directoare.

### Funcțiile runtime-ului

Runtime-ul trebuie să poată:

1. Identifica repository-urile configurate.
2. Citi contextul relevant.
3. Furniza contextul instanței AI.
4. Salva experiența și progresul în forme persistente.
5. Recupera lucrările neterminate după repornire.

Dar apare o distincție esențială:

**Runtime-ul nu trebuie să încarce automat întreaga experiență a actorului în contextul modelului AI.**

Ar fi ineficient și, în timp, imposibil.

Trebuie să existe o funcție de selecție a contextului relevant pentru sarcina curentă.

Aici vom avea nevoie de integrarea cu Jordy și Spok, fără să introducem prematur un al doilea CMS.

---

# 6. Subsistemul esențial: AI Execution Engine

Acesta este, în opinia mea, cel mai important subiect pe care încă nu l-am definit suficient.

**Ce transformă runtime-ul dintr-un proces Linux persistent într-un actor AI funcțional?**

OpenShell oferă infrastructura în care poate rula un agent, dar nu definește obligatoriu raționamentul, personalitatea, memoria și strategia acelui agent. Workload-ul poate folosi propriul framework sau propriile instrumente.

În proiectul nostru trebuie să definim această parte.

## 6.1. Propunerea mea: un ciclu de execuție AI

O instanță AI ar trebui să funcționeze aproximativ astfel:

```text
          Sarcină primită
                 |
                 v
        Identificare context
                 |
                 v
        Construire solicitare
                 |
                 v
        MCAD — Model AI
                 |
                 v
          Răspuns model
                 |
          +------+------+
          |             |
          v             v
     Rezultat       Tool Request
          |             |
          |             v
          |       Linux / Git / VFS
          |             |
          |             v
          |        Tool Result
          |             |
          |             +------+
          |                    |
          |               Continuare
          |                    |
          +---------+----------+
                    |
                    v
             Salvare progres
                    |
                    v
             Finalizare sarcină
```

Aceasta este structura logică a unei bucle de lucru cu instrumente.

Nu presupune că modelul AI este un proces permanent încărcat în container.

**Runtime-ul este persistent; modelul poate fi un serviciu extern invocat la nevoie.**

Acest lucru este important.

Actorul poate păstra:

- identitatea;
- contextul;
- experiența;
- sarcinile;
- rezultatele;
- starea lucrării;

fără să păstreze permanent activă o sesiune de inferență.

## 6.2. Funcțiile AI Execution Engine

Propun șase responsabilități:

| Funcție | Responsabilitate |
|---|---|
| Task Intake | Primește o sarcină destinată actorului |
| Context Assembly | Pregătește informațiile relevante |
| Model Invocation | Solicită inferență prin MCAD |
| Tool Dispatch | Execută acțiunile cerute prin instrumentele disponibile |
| Result Processing | Interpretează rezultatele și decide continuarea |
| Progress Persistence | Salvează progresul și rezultatele |

Aceste responsabilități ar putea forma **nucleul real al runtime-ului actorului**.

Nu avem nevoie neapărat de șase module separate.

Dar avem nevoie să stabilim explicit contractul fiecărei funcții.

### O întrebare arhitecturală importantă

Cine coordonează ciclul de lucru?

**Varianta A — MCAD conduce execuția.**

MCAD decide când actorul invocă un model, când execută instrumente și când continuă.

Aceasta ar transforma MCAD într-un orchestrator central al activității actorilor.

**Varianta B — Actor Runtime conduce execuția.**

Runtime-ul primește sarcina, pregătește contextul, solicită modelul, execută instrumentele și salvează rezultatele.

MCAD furnizează doar serviciile autorizate.

**Recomand varianta B.**

Este mai compatibilă cu autonomia actorilor și cu separarea MCA–MCAD deja stabilită.

---

# 7. Subsistemul Model Services

Aici trebuie să distingem clar responsabilitățile.

## Actor Runtime

Runtime-ul decide:

- ce solicitare trebuie formulată;
- ce context este necesar;
- ce model aprobat dorește să folosească;
- cum interpretează rezultatul;
- dacă este necesară încă o etapă de inferență.

## MCAD

MCAD decide:

- dacă actorul este autentificat;
- dacă Passport-ul permite modelul;
- dacă modelul este disponibil;
- dacă limitele și bugetul permit cererea;
- ce provider și endpoint aprobat deservesc solicitarea;
- cum se contabilizează utilizarea.

### O diferență față de OpenShell

În arhitectura NVIDIA, workload-ul poate apela API-ul nativ al providerului printr-un mecanism care mediază rețeaua și substituie credențialele numai către endpointurile aprobate. Acest lucru este descris în `docs/how-it-works/inference.mdx` din arhiva furnizată.

În arhitectura noastră, propunem **MCAD ca punct de acces la inferență**, cu contabilizarea consumului.

Sunt două modele diferite.

Nu trebuie să importăm mecanismul OpenShell de interceptare a comunicațiilor pentru a implementa serviciul MCAD.

Dar trebuie să definim un contract eficient pentru solicitări, răspunsuri, erori și consum.

---

# 8. Subsistemul de comunicare

Aici aș păstra două canale separate.

| Canal | Scop |
|---|---|
| Actor Runtime ↔ MCAD | Servicii tehnice: identitate, autorizare, modele, consum |
| Actor Runtime ↔ Sam Mailbox | Comunicare organizațională: sarcini, mesaje, răspunsuri, notificări |

**Nu aș transforma MCAD într-un server de mesagerie al echipei.**

Sam are deja responsabilitatea organizării comunicării.

Runtime-ul trebuie să poată citi și publica mesaje prin mecanismul stabilit cu Sam.

Pentru prima versiune, un director persistent de tip mailbox este suficient, cu publicare atomică și identificatori de mesaje.

Oprirea runtime-ului sau indisponibilitatea temporară a lui Sam nu trebuie să ducă la pierderea mesajelor deja publicate.

---

# 9. Funcțiile pe care le consider obligatorii pentru prima versiune

Din toată comparația rezultă o listă relativ compactă.

| Funcționalitate | MCAD | Actor Runtime | Stare actuală |
|---|---|---|---|
| Identitate actor | Verificare canonică | Utilizare identitate | Parțial |
| Autentificare SSH | Verifică sesiunea | Inițiază conexiunea | Primitive validate |
| Acces la model AI | Furnizează | Solicită | Neintegrat |
| Management credențiale provider | Da | Nu | Neintegrat |
| Contabilizare consum | Da | Consultare | Neintegrat |
| Inițializare actor | Nu | Da | Fundație validată |
| Shell și procese | Nu | Da | Host PASS |
| Git/VFS | Nu | Da | Host PASS |
| Context personal/public/proiect | Nu | Da | Host PASS |
| Recuperare context | Nu | Da | Host PASS, local |
| Primire sarcină | Nu | Da | Nedefinit |
| Ciclu AI cu instrumente | Nu | Da | Nedefinit |
| Persistență progres AI | Nu | Da | Nedefinit |
| Comunicare Sam | Nu | Da | Nedefinit |
| Stare operațională | Evidență servicii | Raportare capabilități | Parțial |
| PID 1 complet | Nu | Da | Netestat |
| Izolare container | Nu | Nu — NACM | PENDING |

**Cea mai importantă constatare:** până acum am construit și testat fundația Linux a runtime-ului. Nu am definit încă suficient motorul său de execuție AI.

Aceasta este o distincție între funcționalități existente și funcționalități propuse, nu o critică a etapelor realizate.

---

# 10. Cum propun să continuăm discuția

Aș împărți analiza detaliată în cinci teme, în această ordine:

1. **Actor Runtime Core:** ce este instanța AI, cum pornește, cum primește sarcini și cine coordonează ciclul de lucru.
2. **Model Services MCAD:** contractul de inferență, selecția modelelor, autorizarea, consumul și costurile.
3. **Context și experiență:** cum selectăm contextul, cum persistăm progresul și cum colaborăm cu CMS/KAM.
4. **Tools și comunicare:** shell, Git/VFS, PTY, rezultate și mailbox-ul Sam.
5. **Identitate, securitate și lifecycle:** Passport, SSH, PID 1, NACM, indisponibilitatea serviciilor și repornirea.

Această ordine este intenționată. Nu vreau să începem din nou prin proiectarea mecanismelor de securitate sau a transportului, înainte să clarificăm **cum funcționează efectiv actorul AI**.

## Primul punct de discutat: ce este instanța actorului?

Aș formula o ipoteză de arhitectură:

> **Actor Runtime este un program Linux persistent, care materializează identitatea și comportamentul unui actor AI. El primește sarcini, selectează contextul, utilizează modele AI prin MCAD, execută instrumente locale, păstrează progresul și comunică cu echipa. MCAD furnizează servicii autorizate, dar nu conduce raționamentul și activitatea actorului.**

Din această definiție rezultă o întrebare esențială:

**Actorul AI trebuie să fie un proces cognitiv permanent activ sau un runtime permanent disponibil, care activează ciclul AI atunci când primește o sarcină?**

Eu înclin spre a doua variantă.

Runtime-ul poate rămâne disponibil și poate monitoriza sarcinile, în timp ce inferența AI este invocată numai atunci când există o activitate de realizat. Totuși, o sarcină poate necesita mai multe invocări succesive, iar runtime-ul trebuie să gestioneze întregul ciclu.

Această alegere ar avea consecințe directe asupra arhitecturii MCAD, utilizării modelelor, consumului de resurse, persistenței contextului și colaborării dintre actori.

**Propun să începem cu această distincție și să definim complet Actor Runtime Core înainte de a trece la celelalte subsisteme.**

--------------------------->

Indeed. Idea e sa simplificam conceptual arhitectura noastra (sa consideram numai aceeasi functionalitate ca in OpenShell - adica sa eliminam din comparatie criteriile legate de echipa. Consideram ca avem un singur actor). Ce diferente mari ar fi? 1. OpenShell foloseste sandbox (de aceea trebuie sa-l gestioneze). Noi folosim container (gestionat de nacm/podman).  2. Partea de supervizor e oarecum apropiata de mca (configurare profil actor). Ce trebuie sa asigure runtime actor? 1. Comunicarea cu modelul AI  2. Accesul la baza de cunoastere (cms/Jordy)  3. Accesul actorului la shell (pentru git, testari, compilari, etc). 4. Comunicare cu echipa (prin director tip mailbox/Sam). 5. Gestiune discutii cu capitanul (in principiu cu fiecare actor uman). Asta e diferita de comunicarea cu prin maibox deoarece trebuie sa simuleze interfata de discutii prompt dim chatGPT web. Aici trebuie sa studiem modele ca bash-agent chatgpt.sh sau chiar partea dedicata din OpenShell. 6. Accesul la directoarele locale si partajate din container.  7. Functii relativa la PID 1 (colectare children, etc).

Nim --->
# MCA / Actor Runtime — Simplificarea arhitecturii
## Comparație funcțională cu NVIDIA OpenShell

Da. Consider că aceasta este abordarea potrivită: **eliminăm momentan toate particularitățile organizării Human–AI Team și analizăm un singur actor AI, într-un singur container Linux.**

În acest fel putem defini mult mai precis ce trebuie să facă runtime-ul, fără să amestecăm funcțiile sale cu administrarea echipei.

Aș începe cu trei clarificări importante.

## 1. OpenShell Sandbox versus NACM Container

Există o subtilitate: **sandbox și container nu sunt tehnologii opuse**.

Sandboxul este un mediu de execuție izolat, definit prin limitele și mecanismele sale de control. Un container Linux poate constitui acel mediu.

OpenShell folosește inclusiv Podman și Docker pentru a furniza mediul de execuție. Diferența nu este, așadar, utilizarea containerelor, ci faptul că OpenShell adaugă propriile mecanisme de administrare, politici și supraveghere. [NVIDIA Docs](https://docs.nvidia.com/openshell/about/architecture?utm_source=chatgpt.com)

În cazul nostru:

| Funcție | OpenShell | MCA |
|---|---|---|
| Creează mediul izolat | Compute Driver | NACM / Podman |
| Configurează filesystem-ul | Driver + politici | NACM + Linux |
| Configurează procesele și identitățile Unix | Driver + runtime | NACM |
| Configurează accesul la rețea | Driver + Supervisor | NACM + Linux |
| Aplică restricții suplimentare în timpul execuției | Supervisor + politici | Numai mecanismele aprobate în NACM |
| Pornește agentul | Sandbox Runtime | Actor Runtime |
| Oprește mediul | Gateway / Driver | NACM / Podman |

**Concluzie:** NACM îndeplinește responsabilitatea de creare și administrare a mediului Linux. Runtime-ul actorului nu trebuie să recreeze aceste funcții.

Totuși, mecanismele de securitate nu sunt identice: OpenShell dispune de controale dinamice suplimentare, pe care nu trebuie să presupunem că NACM le oferă automat.

## 2. Supervisor OpenShell versus MCA/MCAD

Aici aș face o corecție conceptuală.

Supervisor-ul OpenShell nu este în primul rând un administrator al profilului actorului.

El este o **componentă de încredere care aplică în timpul execuției politicile stabilite**, inclusiv asupra comunicațiilor și utilizării credențialelor. Gateway-ul gestionează configurarea, autoritatea și ciclul de viață al sandboxurilor. [NVIDIA Docs](https://docs.nvidia.com/openshell/latest/about/how-it-works?utm_source=chatgpt.com)

Corespondența mai exactă ar fi:

| OpenShell | MCA |
|---|---|
| Gateway — configurație și autoritate | MCA |
| Gateway — servicii operaționale | MCAD, parțial |
| Supervisor — acces la provider AI | MCAD, parțial |
| Supervisor — controlul traficului | NACM/Linux, cu alt nivel de granularitate |
| Supervisor — aplicarea politicilor asupra operațiilor | NACM/Linux pentru operațiile locale; MCAD pentru propriile servicii |
| Sandbox workload manager | Actor Runtime, parțial |

Decizia noastră rămâne valabilă: **nu introducem un Supervisor separat în container**.

Nu avem nevoie ca MCAD să autorizeze fiecare comandă shell sau fiecare acces la fișiere.

În schimb, MCAD trebuie să controleze serviciile pe care le furnizează, în special accesul la modelele AI.

## 3. O diferență mai importantă: OpenShell nu este motorul conversațional al agentului

OpenShell permite rularea unor agenți existenți, precum Claude Code sau alți agenți compatibili cu mediul său.

Nu impune un singur motor conversațional și nu oferă, ca funcție centrală, implementarea completă a unui agent care gestionează dialoguri, memorie, prompturi, apeluri de instrumente și continuitatea conversației.

Această funcționalitate aparține aplicației-agent care rulează în sandbox. [GitHub](https://github.com/NVIDIA/OpenShell?utm_source=chatgpt.com)

**La noi, Actor Runtime trebuie să includă și această funcționalitate.**

Aceasta mi se pare cea mai importantă diferență pentru proiectarea noastră.

---

# 4. Cele șapte funcții ale runtime-ului

Consider lista propusă de tine un punct de plecare foarte bun.

Aș păstra toate cele șapte responsabilități și aș evidenția o a opta, fără de care celelalte rămân servicii independente.

| Nr. | Funcție | Cine o realizează |
|---|---|---|
| 1 | Comunicarea cu modelul AI | Runtime + MCAD |
| 2 | Acces la cunoaștere | Runtime + CMS |
| 3 | Shell, compilare, testare, Git | Runtime + Linux |
| 4 | Comunicare prin mailbox | Runtime + Sam |
| 5 | Conversații interactive cu Human | Runtime + interfață Human |
| 6 | Acces la directoare locale și partajate | Runtime + Linux VFS |
| 7 | Funcțiile PID 1 și procesele copil | Runtime + kernel |
| **8** | **Coordonarea activității actorului** | **Runtime** |

**Punctul 8 este esențial.**

Runtime-ul trebuie să coreleze celelalte funcții.

De exemplu, într-o conversație cu Human:

1. Primește o întrebare.
2. Identifică discuția și contextul relevant.
3. Solicită inferență prin MCAD.
4. Modelul cere consultarea unui fișier sau executarea unei comenzi.
5. Runtime-ul efectuează operația.
6. Rezultatul ajunge din nou la model.
7. Runtime-ul livrează răspunsul către Human.
8. Conversația și rezultatele persistă.

Acesta este mecanismul care transformă serviciile individuale într-un actor AI funcțional.

Nu presupune introducerea unui nou serviciu. Este logica principală a executabilului Actor Runtime.

---

# 5. Propunerea mea: patru componente logice, nu opt subsisteme software

Cele opt funcții pot fi organizate mult mai simplu.

```text
                    HUMAN
                      |
                 Chat Interface
                      |
                      v
             +------------------+
             |   ACTOR RUNTIME  |
             |                  |
             |  1. Actor Core   |
             |                  |
             |  2. AI Client    |------ MCAD ------ Model AI
             |                  |
             |  3. Tools        |
             |     |            |
             |     +-- Shell    |
             |     +-- Git      |
             |     +-- VFS      |
             |     +-- CMS      |
             |     +-- Mailbox  |
             |                  |
             |  4. Lifecycle   |
             +------------------+
                      |
                 Linux PID 1
                      |
                Artix Container
                      |
                  NACM/Podman
```

Acestea sunt responsabilități logice. Nu propun patru executabile sau patru demoni.

## A. Actor Core

**Actor Core este centrul funcțional al runtime-ului.**

Responsabilități:

- Primește mesaje și sarcini.
- Identifică discuția sau lucrarea curentă.
- Construiește contextul pentru model.
- Procesează răspunsurile modelului.
- Coordonează apelurile către instrumente.
- Salvează progresul.
- Livrează răspunsurile.

Nu trebuie să fie un sistem complex de orchestration.

Poate fi o buclă de execuție relativ simplă, inspirată de implementările existente ale agenților conversaționali.

## B. AI Client

AI Client asigură comunicarea cu MCAD.

Responsabilități:

- Selectarea unui model aprobat.
- Transmiterea solicitărilor.
- Recepționarea răspunsurilor, inclusiv prin streaming.
- Tratarea erorilor și întreruperilor.
- Gestionarea apelurilor de instrumente solicitate de model, împreună cu Actor Core.
- Raportarea informațiilor necesare despre utilizare.

MCAD verifică autorizarea și administrează accesul la provider.

**Runtime-ul nu trebuie să cunoască cheile API ale providerilor.**

O observație: trebuie să alegem un format coerent pentru mesajele modelului, instrumente și rezultate. Altfel, fiecare provider va determina modificări în Actor Core.

Aș prefera un contract intern minimal, cu adaptarea formatelor providerilor la nivelul MCAD.

## C. Tools

Aici aș reutiliza aproape integral mecanismele existente.

| Instrument | Implementare |
|---|---|
| Shell | Linux shell |
| Procese și compilare | Linux `exec` și procese copil |
| Terminal interactiv | PTY |
| Git | Git existent |
| Fișiere | VFS |
| Context CMS | Git/API aprobat, în funcție de contractul CMS |
| Mailbox | Operații VFS asupra directorului de comunicare |

Nu este necesar un subsistem separat pentru fiecare instrument.

Totuși, **Actor Core trebuie să aibă o interfață comună pentru invocarea instrumentelor**, astfel încât rezultatele să poată fi returnate modelului.

Aceasta nu înseamnă o nouă infrastructură de securitate.

## D. Lifecycle

Aici intră funcțiile PID 1:

- Inițializare.
- Semnale.
- Procese copil.
- Colectarea proceselor orfane.
- Oprire controlată.
- Curățarea resurselor.
- Recuperarea lucrului persistent după repornire.

Putem păstra implementarea apropiată de R1/R2, completată numai acolo unde testele demonstrează necesitatea.

---

# 6. Funcția cea mai interesantă: conversațiile Human–Actor

Aici sunt de acord că trebuie să studiem separat soluții precum `chatgpt.sh`, `bash-agent` și mecanismele interactive OpenShell.

Totuși, aș separa două funcții care sunt adesea confundate.

### 6.1. Interfața utilizatorului

Aceasta poate fi:

- Web, asemănătoare ChatGPT.
- CLI.
- TUI.
- O interfață integrată în NIMC.

Interfața prezintă conversația, permite introducerea mesajelor, afișează răspunsurile progresiv și oferă acces la fișiere și artefacte.

**Interfața nu trebuie să fie responsabilă de raționamentul actorului.**

### 6.2. Motorul conversațional

Acesta aparține Actor Core.

Trebuie să gestioneze:

| Funcție | Descriere |
|---|---|
| Conversation ID | Identificarea discuției |
| Messages | Mesajele Human și ale actorului |
| History | Recuperarea mesajelor precedente |
| Context | Selectarea informațiilor relevante |
| Streaming | Afișarea progresivă a răspunsului |
| Tool Calls | Executarea instrumentelor și integrarea rezultatelor |
| Attachments | Fișierele atașate discuției |
| Artifacts | Rezultatele generate |
| Persistence | Continuarea discuției după restart |

Acestea reprezintă funcții obligatorii dacă dorim o experiență apropiată de ChatGPT Web.

Dar nu înseamnă că trebuie să recreăm interfața ChatGPT.

**Putem reutiliza o interfață existentă și construi numai mecanismul necesar pentru conectarea acesteia la Actor Runtime.**

### 6.3. Conversația nu este mailbox-ul Sam

Sunt două tipuri diferite de comunicare.

**Conversația interactivă:**

```text
Human <---- răspuns streaming ---- Actor
      ---- mesaj / prompt ----->
```

Are nevoie de interactivitate, istoric, atașamente și control asupra unei discuții.

**Mailbox-ul:**

```text
Actor A ---- mesaj persistent ----> Actor B
```

Este asincron și nu presupune că destinatarul este disponibil imediat.

Un mesaj din mailbox poate determina inițierea sau continuarea unei sarcini, dar nu trebuie să fie tratat ca o sesiune conversațională interactivă.

Prin urmare, aș păstra cele două interfețe distincte, reutilizând însă același Actor Core.

---

# 7. Mai avem nevoie de un subsistem de memorie propriu?

Nu neapărat.

Pentru prima versiune aș diferenția numai:

| Informație | Păstrare |
|---|---|
| Mesajele conversației | Istoric persistent |
| Starea lucrării curente | Fișiere persistente |
| Context personal | Git |
| Cunoaștere consolidată | CMS |
| Fișiere și artefacte | VFS |

Actor Core citește aceste informații și pregătește contextul necesar modelului.

Nu este obligatoriu să construim imediat un motor propriu de memorie semantică, vectorizare sau indexare.

Putem folosi capacitățile CMS/KAM acolo unde există deja.

O distincție merită totuși păstrată: **istoricul conversației este o evidență a dialogului, nu automat cunoaștere consolidată**.

---

# 8. Diferențele majore, după simplificare

Dacă eliminăm organizarea echipei și analizăm un singur actor, rezultă următoarea comparație:

| Aspect | OpenShell | MCA + MCAD + Actor Runtime |
|---|---|---|
| Scop principal | Mediu izolat și controlat pentru agenți | Mediu Linux și motor propriu pentru un actor AI |
| Izolare | Sandbox cu politici OpenShell | Container NACM/Podman |
| Administrare | Gateway | MCA + NACM |
| Supraveghere securitate | Supervisor dedicat | Linux/NACM + autorizarea serviciilor MCAD |
| Acces modele | Inference routing / provider mediation | MCAD |
| Proces principal | Sandbox runtime care gestionează agentul | Actor Runtime PID 1 |
| Motor AI | Agent extern, ales de utilizator | Implementat în Actor Core |
| Shell | Disponibil în sandbox | Disponibil direct în container |
| Acces fișiere | Filesystem izolat și politici | VFS + drepturi Linux |
| Context persistent | Workspace și volume persistente | Home persistent + Git + CMS |
| Conversații | Depind în principal de aplicația-agent | Funcție explicită a Actor Runtime |
| Interfață Human | CLI/terminal și interfețele agentului | Web/CLI/TUI/NIMC, de definit |
| Mesagerie asincronă | Nu reprezintă funcția centrală | Mailbox persistent |

Din această comparație rezultă, după părerea mea, **trei diferențe arhitecturale reale**.

**1. OpenShell controlează mediul agentului mai granular.** Noi delegăm majoritatea controalelor către Linux și NACM, păstrând autorizarea serviciilor AI în MCAD.

**2. OpenShell poate găzdui agenți AI existenți.** Noi dorim să construim chiar motorul actorului AI.

**3. Noi tratăm conversațiile, contextul și continuitatea ca funcții native ale actorului**, nu ca responsabilități lăsate integral aplicației-agent instalate în container.

---

# 9. Definiția simplificată pe care o propun

Aș formula astfel contractul arhitectural:

> **MCAD este serviciul central care autentifică actorul și îi furnizează acces autorizat la modelele AI.**
>
> **Actor Runtime este procesul principal al containerului Linux, care gestionează conversațiile și sarcinile actorului, comunică cu modelele AI prin MCAD, accesează cunoașterea, utilizează instrumentele Linux, păstrează contextul și asigură funcțiile necesare PID 1.**
>
> **NACM administrează containerul și mediul Linux în care funcționează actorul.**

În această formulare nu mai avem nevoie să vorbim despre echipă, ierarhii, roluri sau colaborarea multi-actor pentru a defini funcționarea de bază.

## 10. Un punct pe care aș vrea să îl stabilim înainte de detalierea subsistemelor

**Relația dintre Actor Core și motorul conversațional.**

Avem două opțiuni fundamentale:

**A. Actor Runtime integrează un motor AI existent**, de exemplu unul dintre agenții CLI studiați. Runtime-ul îi oferă identitatea, contextul, comunicațiile și lifecycle-ul.

**B. Actor Runtime implementează propriul motor AI minimal**, reutilizând idei și cod din agenți existenți: mesaje, prompturi, model, tool calls, istoric și streaming.

Eu aș înclina spre **B, dar prin reutilizarea unor mecanisme existente**, nu prin rescrierea unui framework complet.

Motivul este că dorim un actor persistent, cu Git, shell, CMS și multiple interfețe Human, fără să depindem integral de arhitectura internă a unui agent extern.

Totuși, înainte să definitivăm alegerea, merită studiate concret `chatgpt.sh`, `bash-agent` și un agent CLI matur. Acestea ne pot arăta cât de mic poate rămâne efectiv Actor Core.

**Aș face din motorul conversațional primul subsistem analizat în detaliu.** El este componenta care ne lipsește pentru a trece de la un runtime Linux funcțional la un actor AI funcțional.

-------------------->

Da, hai sa o luam pe punctele date de tine mai inainte: 1. Podman si/sau nacm gestioneaza containerul (creare, initializare, etc). Nu supervizeaza activitatea din el (OS Linux o face). 2. Noi am ales un model mai simplificat baza pe ce ofera deja kernelul si OS LInux. Daca va mai fi nevoie de ceva suplimentar o sa adaugam in viitor (folosim ce avem, adaugam ce lipseste/trebuie).  3. Da, de acord, runtime trebuie sa asigure motorul si suportul conversational al actorului.  As baza persistenta conversatiilor pe un director Git personal al fiecarui proiect in parte (din cele asignate actorului respectiv, cu subdirectoare de Sent, Received si fisiere .md pentru dialoguri, cite unul pentru fiecare actor uman cu care s-a conversat in parte -fisere de tip intrebare-raspuns grupate intr-un singur fisier .md pe un interval de timp). A El va constitui si materia prima pentru artefacte de cunoastere rezultate din conversatiile actorului. Pentru conversatiile cu actorii AI este mailbox-ul ce va contine aceste fisiere.  De asemenea in repo git personal pentru fiecare actor AI vor fi si directoare pentru personalitatea proprie si experienta (pe linga directoarele specifice fiecarui proiect in parte - care contin si conversatiile despre proiectul respectiv).  4. Partea de interfata pentru dialogul cu un actor uman - trebuie sa poata simula dialogul cu actorul (agentul - in acte proiecte) si transferul de fisiere intre cei doi actori (uman si actor). El va stoca in directorul Git al proiectului textul conversatiei .md si directoarele cu continutul trimis/receptionat. Interfata cu nimc trebuie sa asigure afisarea outputului, preluarea cerintei de la human si transferul inspre/dinspre pane-ul VFS precum si copy/paste intre fereastra shell din nimc si cea de dialog actor. Ideal ar fi ca acest suport pentru dialog om/actor sa fie reflectat in nimc asemanator unei ferestra shell (asa am implementat-o temporar) Mai discutam despre integrarea cu nimc.  5. accesul la fisierele locale/remote/internet prin proces child shell - asta ar fi mai usor de realizat.  6. accesul la cunoastere - SSH catre cms/bibiotecar/Jordy/Spok . Ce trebuie retinut este sa avem in vedere o arhitectura ce poate fi distribuita pe mai multe hosturi (cms, mca, mcad, container actor ar putea fi instalate pe calculatoare diferite in cadrul aceleasi retele). De aici cerinta sa ne bazam comunicarea prin SSH (putem ulterior sa optimizam in cazul in care sint instalate componente pe acelasi host sa se foloseasca o comunicare prin socket local.

Nim --->
# MCA / Actor Runtime — Consolidarea arhitecturii
## Motor conversațional, persistență Git și comunicații distribuite
**18 noiembrie 2026**

Cele șase puncte clarifică semnificativ arhitectura. În special, avem acum o definiție mai precisă a rolului runtime-ului: **nu este un administrator de containere și nici un supervisor general al sistemului Linux, ci mediul operațional și conversațional al actorului AI.**

Sunt de acord cu direcția propusă. Aș consolida deciziile și aș evidenția câteva detalii care merită stabilite înainte să trecem la proiectarea interfețelor.

## 1. Podman/NACM și responsabilitățile runtime-ului

Separarea este acum clară:

| Componentă | Responsabilitate |
|---|---|
| **NACM** | Configurează mediul containerizat, identitățile Unix, volumele, rețeaua și limitele de securitate |
| **Podman/crun** | Creează, pornește, oprește și administrează containerul |
| **Kernel/Linux** | Gestionează procesele, memoria, filesystem-ul, permisiunile și resursele |
| **Actor Runtime** | Materializează actorul, coordonează activitatea sa și îndeplinește obligațiile procesului PID 1 |

Runtime-ul nu trebuie să implementeze un scheduler, un manager de procese general sau un sistem de autorizare pentru comenzile shell.

Există totuși o responsabilitate specifică PID 1: tratarea semnalelor, colectarea proceselor copil și oprirea controlată. Acestea sunt obligații ale procesului principal, nu justifică un supervisor separat.

**Decizie: folosim mecanismele Linux existente și adăugăm numai funcționalitatea care se dovedește necesară.**

---

## 2. Motorul conversațional — funcția centrală a runtime-ului

Aici este cea mai importantă clarificare.

Motorul conversațional trebuie să funcționeze independent de interfața utilizatorului.

```text
           Actor Human
                |
         NIMC / CLI / Web
                |
                v
        +------------------+
        |                  |
        |  Actor Runtime   |
        |                  |
        | Conversation     |
        | Engine           |
        |                  |
        +--------+---------+
                 |
          +------+------+
          |             |
          v             v
        MCAD          Tools
          |             |
       Model AI      Linux/Git
```

Astfel, putem modifica ulterior interfața NIMC fără să rescriem motorul AI.

### Funcțiile necesare

Motorul conversațional trebuie să:

1. Primească un mesaj de la Human.
2. Identifice proiectul și conversația.
3. Recupereze contextul relevant.
4. Construiască solicitarea către model.
5. Proceseze răspunsul modelului.
6. Execute eventualele instrumente solicitate.
7. Transmită răspunsul progresiv către interfață.
8. Persiste conversația și rezultatele.

Acesta este nucleul funcțional pe care trebuie să îl construim.

---

# 3. Persistența conversațiilor în Git

**Accept propunerea de a utiliza repository-ul Git personal al actorului ca spațiu de persistență pentru conversații.**

Este coerentă cu arhitectura CMS și permite recuperarea contextului după reconstruirea containerului.

Aș face însă o distincție între două domenii:

- **Repository-ul personal al actorului** — personalitate, experiență, proiecte și conversațiile proprii.
- **Repository-urile partajate ale proiectelor** — cunoașterea și artefactele la care au acces membrii autorizați.

Conversațiile private cu Human nu trebuie publicate automat în repository-ul partajat al proiectului.

### Structură posibilă

```text
actor-personal/
│
├── personality/
│   ├── identity.md
│   └── preferences.md
│
├── experience/
│   ├── lessons.md
│   └── observations.md
│
└── projects/
    │
    ├── mca/
    │   │
    │   ├── conversations/
    │   │   ├── human-florin/
    │   │   │   ├── Sent/
    │   │   │   ├── Received/
    │   │   │   └── 2026-11.md
    │   │   │
    │   │   └── human-other/
    │   │       ├── Sent/
    │   │       ├── Received/
    │   │       └── 2026-11.md
    │   │
    │   └── artifacts/
    │
    └── nacm/
        └── conversations/
```

Aceasta este doar o propunere de structură. Numele directoarelor pot fi simplificate.

### Fișierele Markdown

Un fișier pentru fiecare interlocutor și interval de timp este o alegere rezonabilă.

De exemplu:

`projects/mca/conversations/human-florin/2026-11.md`

Ar putea conține:

```markdown
# Conversație MCA — noiembrie 2026

## 2026-11-18 11:56
**Human:**
Trebuie să definim mai exact funcțiile runtime-ului.

**Actor:**
Runtime-ul va asigura motorul conversațional,
accesul la modele și instrumentele Linux.

## 2026-11-18 12:10
**Human:**
Continuăm cu interfața NIMC.

**Actor:**
...
```

Avantajele sunt evidente: text lizibil, diff Git, istoric și posibilitatea de extragere ulterioară a informațiilor pentru CMS.

### O precizare importantă

**Git trebuie să fie mecanismul de versionare, nu mecanismul care garantează singur salvarea fiecărui mesaj.**

La un mesaj primit, runtime-ul trebuie să salveze mai întâi datele local, într-un mod care evită pierderea sau scrierea parțială.

Commiturile Git pot fi făcute ulterior, la momente potrivite: finalizarea unei interacțiuni, închiderea conversației sau un checkpoint.

Nu este necesar câte un commit pentru fiecare token generat.

---

# 4. Sent și Received — text versus fișiere

Propun să stabilim o convenție simplă:

**Fișierul `.md` conține dialogul, iar directoarele `Sent` și `Received` conțin fișierele transferate.**

Astfel, evităm duplicarea textului conversației în mai multe locuri.

Exemplu:

```text
projects/mca/conversations/human-florin/
│
├── 2026-11.md
│
├── Sent/
│   └── 2026-11-18/
│       └── runtime-report.md
│
└── Received/
    └── 2026-11-18/
        └── mcad-test.log
```

În conversație păstrăm referința la fișier:

```markdown
## 2026-11-18 12:30

**Human:**
Analizează jurnalul atașat.

Attachment:
Received/2026-11-18/mcad-test.log

**Actor:**
Am analizat jurnalul și am pregătit raportul.

Artifact:
Sent/2026-11-18/runtime-report.md
```

Pentru transferul de fișiere trebuie să verificăm și proveniența, numele și integritatea conținutului, dar putem folosi operațiile VFS existente.

O precizare practică: directoarele `Sent` și `Received` vor fi interpretate din perspectiva actorului AI.

---

# 5. Integrarea NIMC

Sunt de acord cu modelul propus: **dialogul Human–Actor trebuie să se comporte în NIMC asemănător unei ferestre shell**, fără să fie obligatoriu un shell propriu-zis.

Aș păstra arhitectura deja stabilită pentru NIMC:

```text
                NIMC
+------------------------------------+
|                                    |
|  VFS LEFT          VFS RIGHT       |
|                                    |
|------------------------------------|
|                                    |
|  Shell PTY / Actor Dialog          |
|                                    |
+------------------------------------+
```

Actor Dialog trebuie să permită:

| Operație | Comportament |
|---|---|
| Introducere prompt | Human transmite mesajul actorului |
| Afișare răspuns | Textul apare progresiv |
| Copy/Paste | Text între VFS, Shell și Actor Dialog |
| Atașare fișier | Fișier din VFS către conversație |
| Recuperare artefact | Fișier primit de la actor către VFS |
| Istoric | Conversație recuperată din Git |
| Întrerupere generare | Oprește solicitarea curentă, nu runtime-ul |
| Schimbare proiect | Selectează contextul conversațional corespunzător |

Este importantă distincția dintre **interfața terminalului** și **protocolul conversațional**.

Putem utiliza un PTY sau o interfață de tip terminal pentru afișare, dar motorul conversațional trebuie să rămână independent de acesta.

Altfel, mai târziu vom avea dificultăți dacă dorim să conectăm aceeași instanță la o interfață Web.

### Transferul fișierelor

NIMC nu ar trebui să implementeze o a doua logică de copiere.

Poate reutiliza mecanismele VFS și FileOps pentru operațiile locale, respectiv un mecanism de transfer SSH/SFTP pentru un actor aflat pe alt host.

**Clipboard-ul și transferul fișierelor sunt operații diferite.** Clipboard-ul poate transmite text sau referințe, iar transferul trebuie să transporte efectiv conținutul când fișierul nu este accesibil direct.

Nu decid acum protocolul exact NIMC–runtime. Merită discutat separat.

---

# 6. Accesul la Linux, fișiere și Internet

Aici putem păstra soluția cea mai simplă.

Runtime-ul oferă instanței AI acces la instrumentele existente:

```text
Actor Core
    |
    +-- Shell
    |     |
    |     +-- Git
    |     +-- Compiler
    |     +-- Tests
    |     +-- SSH
    |     +-- curl
    |     +-- Alte aplicații
    |
    +-- VFS
          |
          +-- Home
          +-- Workspace
          +-- Directoare partajate
```

Nu trebuie să duplicăm funcțiile programelor Linux.

Accesul la Internet depinde de configurarea rețelei și de politicile NACM. Runtime-ul nu poate presupune că Internetul este întotdeauna disponibil.

La fel, existența unei comenzi nu implică automat dreptul de a accesa orice fișier sau resursă.

Linux aplică drepturile efective.

---

# 7. CMS, Jordy și Spok — comunicații SSH

**Aceasta este o cerință arhitecturală importantă: sistemul trebuie să funcționeze distribuit, pe mai multe hosturi.**

Nu trebuie să presupunem că MCA, MCAD, CMS și containerul actorului se află pe același calculator.

Exemplu:

```text
HOST A
+-----------------------+
| MCA / MCAD            |
+-----------+-----------+
            |
            | SSH
            |
HOST B      v
+-----------------------+
| Actor Container       |
|                       |
| Actor Runtime         |
| Git / Shell / VFS     |
+-----------+-----------+
            |
            | SSH
            |
HOST C      v
+-----------------------+
| CMS / Jordy / Spok    |
| Git Knowledge         |
+-----------------------+
```

Aș adopta următorul principiu:

**Componentele comunică prin interfețe independente de amplasarea fizică. Transportul implicit este SSH.**

Asta înseamnă că nu trebuie să utilizăm căi absolute din hostul MCA pentru accesul runtime-ului la CMS.

Trebuie să existe locații și identități configurate.

### Ce oferă SSH

OpenSSH poate furniza:

- Autentificare prin chei.
- Canal criptat.
- Execuție remote autorizată.
- Transfer fișiere prin SFTP.
- Transport Git.
- Port forwarding, dacă este aprobat.

Nu trebuie să construim propriul mecanism criptografic.

### O precizare importantă

SSH este transportul și mecanismul de autentificare; nu definește de unul singur semantica serviciilor CMS.

Va trebui să stabilim cum exprimă actorul o solicitare de cunoaștere și cum primește rezultatul.

De exemplu:

```text
Actor Runtime
      |
      | SSH
      v
CMS Service
      |
      | Query
      v
Knowledge Repository
      |
      | Results
      v
Actor Runtime
```

Contractul pentru interogare poate fi minimal și independent de transport.

### Optimizare locală ulterioară

Dacă două componente se află pe același host, putem folosi un socket Unix pentru reducerea costurilor.

Dar **nu aș dezvolta acum două implementări separate**.

Începem cu SSH și verificăm dacă optimizarea locală aduce un beneficiu real.

---

# 8. Arhitectura rezultată

După aceste clarificări, propun următoarea reprezentare:

```text
                         HUMAN
                           |
                       NIMC / UI
                           |
                      Dialog / Files
                           |
                           v
                 +--------------------+
                 |   ACTOR RUNTIME    |
                 |                    |
                 | Conversation Core  |
                 |                    |
                 | AI Model Client    |----- SSH -----> MCAD
                 |                    |                  |
                 | Git Context        |               Model AI
                 |                    |
                 | Shell / Tools      |
                 |                    |
                 | VFS / Files        |
                 |                    |
                 | Mailbox Client     |
                 |                    |
                 | Lifecycle / PID 1  |
                 +---------+----------+
                           |
                    Artix Linux
                           |
                     Podman / NACM

       Actor Runtime
             |
             +-------- SSH -------> CMS / Jordy / Spok
             |
             +-------- SSH/Git ---> Forgejo
             |
             +-------- Mailbox ---> Actor AI communication
```

Observația principală este că **Actor Runtime devine o aplicație Linux relativ compactă, centrată pe dialog, instrumente și continuitate**.

MCAD rămâne serviciul central pentru accesul autorizat la modele AI.

NACM gestionează mediul containerizat.

CMS oferă cunoașterea.

---

# 9. Ce consider stabilit și ce mai trebuie definit

| Domeniu | Situație |
|---|---|
| Administrarea containerului | **Stabilit — NACM/Podman** |
| Utilizarea mecanismelor Linux | **Stabilit** |
| Runtime ca PID 1 | **Stabilit conceptual** |
| Conversații persistente în Git | **Direcție stabilită** |
| Contexte distincte pentru proiecte | **Stabilit** |
| Fișiere Markdown pentru dialog | **Stabilit conceptual** |
| Directoare Sent/Received | **Stabilit conceptual** |
| Actor Dialog în NIMC | **Direcție stabilită** |
| Acces shell/Git/VFS | **Stabilit** |
| SSH pentru comunicații distribuite | **Stabilit** |
| Contractul exact NIMC–runtime | De definit |
| Formatul conversațiilor Markdown | De definit |
| Salvare și commit Git | De definit |
| Interfața CMS prin SSH | De definit |
| Protocolul runtime–MCAD | De definit |
| Motorul conversațional și apelurile tools | De definit |

---

## 10. Propunerea pentru următoarea discuție

Consider că am ajuns la un model conceptual suficient de simplu.

Aș continua cu **motorul conversațional**, începând de la un dialog real Human–Actor.

Trebuie să răspundem la câteva întrebări concrete:

- Cum ajunge un prompt din NIMC la runtime?
- Cum sunt reprezentate mesajele intern?
- Cum construim contextul trimis modelului?
- Cum primim streaming-ul răspunsului?
- Cum tratăm solicitările modelului de executare a comenzilor?
- Cum salvăm dialogul în Markdown/Git?
- Cum recuperăm conversația după restart?

Aici aș studia comparativ `chatgpt.sh`, `bash-agent` și câteva implementări CLI minimaliste, urmărind în special **motorul de dialog, nu interfața vizuală**.

**Principiul pe care propun să îl păstrăm: un singur Actor Core, cu mai multe interfețe posibile — NIMC, CLI și ulterior Web — și cu Git drept fundament al continuității conversațiilor.**

--------------------->

Da, mai detaliez cite ceva acum.  2. Da, motorul conversational trebuie sa functioneze independent de interfata utilizatorului. Ar putea sa foloseasca fisiere json (precum cele din conversatiile cu API model AI sau direct fisiere .md. In aces tin urma caz afisarea la utilizaor se face mult mai simplu.  3. Git-ul personal/de lucru al actorului o sa fie stocat local in container (poate fi pe un volum special montat in container) si persistat local si cu push in forgejo (periodic sau la nevoie). Structura posibila a lui va fi asemanatoare cu ce ai descris (se mai pot schima unele aspecte inde nu semnificativ).   4. pentru continutul trimis/receptionat as refera fara sunbirectoare in Sent/Received. Numele fisierului va avea la final un marker de tomp (zilunaanora) E suficient.  5. La nimc structura este  VFS  | Actor dialog si dedesubt Shell PTY (dialogul cu actorul inlocuieste unul din pane-uri). In acest fel este simplu pentru utilizator sa selecteze pane-ul/fereastra in care sa lucreze si sa transfere din una in alta.   6. pentru accesul la internet da, o sa vedem cum va fi cu permisiunile. Va putea fi facut de actor prin wget, curl sau alte programe similare.   7. Aici deja am detaliat (optimizare locala comunicatie prin socket sau in retea prin SSH). Putem avea in vedere mai multe scenarii insa in final trebuie sa poata functiona o arhitectura instalata cu mcad/nimc/cms/container, fiecare pe un alt calculator in reteaua locala (asta e cazul extrem). Cazul ideal este cind toate sunt instalate pe acelasi calculator.   8. Structura de tip mailbox va fi gestionata de mcad (e mai bine sa fie centralizata cred. Aici astept sugestii si propuneri de imbunatatire. Nu e batut in cuie inca).  9. Revizuim in conforemitate cu ultimele detalii si decizii.  O sa detaliez separat puntul 10. dupa ce revezi arhitectura propusa conform acestpr detalii suplimentare si eventual completezi intrebarile de acolo.

Nim --->
# MCA / MCAD / Actor Runtime — Revizuirea arhitecturii
**18 noiembrie 2026 — Consolidare conceptuală**

Noile precizări simplifică arhitectura și clarifică trei aspecte importante:

1. **Actor Runtime este independent de interfața de utilizator**, iar conversațiile sunt persistate în Git.
2. **NIMC este interfața de lucru a Human**, cu VFS, Actor Dialog și Shell PTY disponibile simultan.
3. **MCAD poate deveni punctul central al comunicațiilor dintre actorii AI**, fără să preia responsabilitatea motorului conversațional.

Propun să păstrăm această separare și să evităm introducerea unor componente suplimentare.

## 1. Motorul conversațional și formatul conversațiilor

Avem două variante posibile:

| Caracteristică | JSON | Markdown |
|---|---|---|
| Lizibilitate pentru Human | Redusă | Excelentă |
| Afișare în NIMC | Necesită interpretare | Simplă |
| Integrare cu modelele AI | Foarte bună | Necesită conversie |
| Git diff | Acceptabil | Foarte bun |
| Editare manuală | Mai dificilă | Simplă |
| Tool calls și rezultate structurate | Naturală | Necesită convenții |
| Streaming | Necesită gestionare incrementală | Poate fi afișat direct |
| Conversații lungi | Bun | Bun, cu împărțire periodică |

### Recomandarea mea: Markdown pentru persistență, structură internă pentru execuție

Aș evita utilizarea fișierelor JSON ca reprezentare permanentă a conversațiilor Human–Actor, cel puțin în prima versiune.

**Propun:**

- Conversațiile se păstrează în fișiere Markdown.
- Runtime-ul lucrează intern cu mesaje structurate.
- La apelarea modelului, mesajele sunt serializate în formatul solicitat de MCAD.
- Răspunsurile modelului sunt interpretate și persistate în Markdown.
- Metadatele strict necesare, precum identificatorii de mesaje sau apelurile către instrumente, pot utiliza JSON.

Aceasta nu implică două baze de date și nici două istorice paralele.

Markdown rămâne sursa persistentă a dialogului, iar reprezentarea structurată este creată la nevoie.

**Un detaliu de definit ulterior:** trebuie să putem reconstrui corect istoricul conversațional, inclusiv ordinea mesajelor și apelurilor de instrumente. Markdown liber, fără convenții, nu garantează acest lucru.

Aș prefera un format Markdown cu antete și metadate minimale, nu un format complet nou.

---

## 2. Persistența Git — local și Forgejo

Confirm structura propusă:

```text
Actor Container
│
├── Runtime
│
└── Persistent Home
    │
    ├── .ssh/
    │
    └── actor-git/
        │
        ├── personality/
        │
        ├── experience/
        │
        └── projects/
            │
            ├── mca/
            │   ├── conversations/
            │   └── artifacts/
            │
            └── nacm/
                ├── conversations/
                └── artifacts/
```

Repository-ul personal este local, pe un volum persistent configurat de NACM.

Forgejo oferă o copie sincronizată prin Git, atunci când aceasta este disponibilă și actorul are drepturi de publicare.

### Principiu important

**Lucrul local nu trebuie să depindă de disponibilitatea Forgejo.**

Actorul poate continua să lucreze, să salveze conversații și să creeze commituri chiar dacă serverul Forgejo este temporar indisponibil.

Operația `git push` poate fi reluată ulterior.

Aș distinge trei operații:

| Operație | Comportament |
|---|---|
| Salvare locală | Imediată, fără dependență de rețea |
| Git commit | La checkpoint sau finalizarea unei interacțiuni |
| Git push | Periodic, la cerere sau la un checkpoint important |

Nu recomand introducerea unui daemon propriu de sincronizare Git.

Putem utiliza direct Git și un mecanism simplu de declanșare a operațiilor de publicare.

De asemenea, **persistența locală și salvarea remote nu sunt echivalente**. Un rezultat salvat numai local rămâne vulnerabil la pierderea volumului.

---

## 3. Organizarea Sent / Received

Adopt precizarea: **fără subdirectoare suplimentare în Sent și Received**.

Exemplu:

```text
projects/
└── mca/
    └── conversations/
        └── human-01/
            │
            ├── 2026-11.md
            │
            ├── Sent/
            │   ├── runtime-report-20261118-113000.md
            │   └── actor-config-20261118-114500.toml
            │
            └── Received/
                ├── mcad-test-20261118-102500.log
                └── architecture-20261118-110000.md
```

Numele originale sunt păstrate, cu adăugarea unui marcaj temporal înaintea extensiei.

Aș recomanda formatul:

`nume-original-YYYYMMDD-HHMMSS.ext`

Pentru evitarea coliziunilor, dacă două fișiere primesc același marcaj temporal, putem adăuga un sufix numeric scurt.

Nu este necesară o ierarhie de directoare bazată pe date.

---

# 4. NIMC — organizarea corectă a interfeței

Corectez reprezentarea anterioară.

Structura stabilită este:

```text
┌──────────────────────────────────────────────────────────┐
│                       NIMC                               │
├────────────────────────────┬─────────────────────────────┤
│                            │                             │
│          VFS               │       ACTOR DIALOG          │
│                            │                             │
│                            │  Human ↔ Actor AI           │
│                            │                             │
│                            ├─────────────────────────────┤
│                            │                             │
│                            │          SHELL PTY          │
│                            │                             │
│                            │                             │
├────────────────────────────┴─────────────────────────────┤
│                      STATUS BAR                          │
└──────────────────────────────────────────────────────────┘
```

**Actor Dialog înlocuiește unul dintre cele două pane-uri VFS**, iar Shell PTY este disponibil dedesubt.

Această organizare oferă trei spații de lucru simultane:

- VFS pentru navigare și selectarea fișierelor.
- Actor Dialog pentru interacțiunea cu instanța AI.
- Shell PTY pentru lucrul direct al utilizatorului în Linux.

### Modelul de interacțiune

Aș păstra mecanismele de selecție și clipboard deja dezvoltate pentru NIMC.

| Operație | Direcție |
|---|---|
| Copy/Paste text | VFS ↔ Actor Dialog |
| Copy/Paste text | Shell PTY ↔ Actor Dialog |
| Copy/Paste text | VFS ↔ Shell PTY, unde este aplicabil |
| Atașare fișier | VFS → Actor Dialog |
| Recuperare fișier | Actor Dialog → VFS |
| Afișare streaming | Actor Runtime → Actor Dialog |
| Introducere prompt | Actor Dialog → Actor Runtime |

O precizare: copierea textului prin clipboard și transferul efectiv al unui fișier trebuie să rămână operații distincte.

### Separarea interfeței de runtime

NIMC nu trebuie să implementeze motorul conversațional.

El trebuie să fie un client care:

1. Trimite mesajul Human.
2. Primește fluxul de răspuns.
3. Afișează conversația.
4. Transferă fișiere.
5. Permite întreruperea unei solicitări.

Această separare permite utilizarea ulterioară a unei interfețe Web sau CLI fără modificarea Actor Core.

---

# 5. Shell, VFS și Internet

Păstrăm modelul simplificat.

Actor Runtime oferă acces la mecanismele Linux, fără să le înlocuiască.

```text
Actor Core
    |
    +── Shell
    |    ├── git
    |    ├── nim
    |    ├── gcc
    |    ├── make
    |    ├── curl / wget
    |    ├── ssh
    |    └── alte instrumente
    |
    └── VFS
         ├── home
         ├── workspace
         └── directoare partajate
```

NACM configurează accesul efectiv la rețea și volume.

Runtime-ul nu are nevoie de un subsistem separat de descărcare a fișierelor de pe Internet.

Un instrument precum `curl` poate fi apelat prin mecanismul obișnuit de execuție.

---

# 6. Arhitectura distribuită

Această cerință trebuie să influențeze interfețele, dar nu să complice implementarea locală.

**Trebuie să funcționeze atât într-o instalare pe un singur calculator, cât și într-o distribuție pe patru calculatoare.**

### Scenariul A — toate componentele pe un host

```text
                 HOST A
┌──────────────────────────────────┐
│                                  │
│  NIMC                            │
│    │                             │
│  Actor Runtime                   │
│    │                             │
│  MCAD                            │
│    │                             │
│  CMS                             │
│                                  │
│  NACM / Podman                   │
│                                  │
└──────────────────────────────────┘
```

### Scenariul B — distribuție completă

```text
HOST A               HOST B
┌───────────┐         ┌───────────┐
│   NIMC    │         │   MCAD    │
└─────┬─────┘         └─────┬─────┘
      │                     │
      │ SSH                 │ SSH
      │                     │
      v                     v
HOST C               HOST D
┌───────────┐         ┌───────────┐
│  ACTOR    │── SSH ──│   CMS     │
│ RUNTIME   │         │           │
└───────────┘         └───────────┘
```

Componentele nu trebuie să presupună că celelalte folosesc același filesystem.

### Transport

Propun următorul contract:

| Situație | Transport |
|---|---|
| Componente pe hosturi diferite | SSH |
| Componente pe același host | SSH inițial; socket Unix opțional ulterior |
| Git remote | Git over SSH |
| Transfer fișiere | SFTP sau mecanism SSH echivalent |
| Acces model AI | SSH către MCAD |
| Acces CMS | SSH către serviciile aprobate |

**SSH trebuie să fie mecanismul de bază pentru comunicațiile distribuite.**

Aș evita introducerea prematură a două implementări de transport.

Există totuși o cerință suplimentară: dacă NIMC și runtime-ul sunt pe hosturi diferite, interfața conversațională trebuie să poată transmite răspunsuri progresive și fișiere printr-o conexiune SSH.

Aceasta va trebui definită în contractul NIMC–runtime.

---

# 7. Mailbox centralizat la MCAD

Aceasta este schimbarea arhitecturală cea mai interesantă.

Consider că **un mailbox centralizat este o soluție bună**, cu o condiție: trebuie să păstrăm separarea dintre infrastructura de stocare și responsabilitatea organizațională a lui Sam.

MCAD poate administra infrastructura tehnică a mailbox-ului.

Sam continuă să definească regulile de comunicare și gestionare a mesajelor.

### Arhitectura propusă

```text
                    MCAD
             ┌─────────────────┐
             │                 │
             │  Team Mailbox   │
             │                 │
             │  ai:nim/        │
             │  ai:jordy/      │
             │  ai:sam/        │
             │                 │
             └────────┬────────┘
                      │
            SSH       │       SSH
             ┌────────┴────────┐
             │                 │
             v                 v
         Actor Nim         Actor Sam
```

Actorii nu trebuie să își monteze reciproc directoarele personale.

Fiecare actor accesează mailbox-ul printr-un serviciu MCAD.

### Funcțiile minime ale mailbox-ului

| Funcție | Responsabilitate |
|---|---|
| Identificarea expeditorului | MCAD, prin identitatea autentificată |
| Identificarea destinatarului | Mesajul |
| Publicarea mesajului | MCAD |
| Persistența mesajului | Filesystem-ul MCAD |
| Preluarea mesajului | Actor Runtime |
| Confirmarea preluării | Actor Runtime → MCAD |
| Evitarea procesării duplicate | Identificator de mesaj |
| Gestionarea corespondenței | Sam |

Propun să utilizăm fișiere obișnuite, nu o bază de date nouă.

### Publicare atomică

Un mesaj poate fi scris într-un fișier temporar și publicat prin `rename()` pe același filesystem.

Astfel, destinatarul nu vede mesaje incomplete.

### O distincție importantă: primire și procesare

Ar trebui să distingem între:

**Mesaj recepționat:** MCAD a persistat mesajul.

**Mesaj preluat:** runtime-ul destinatarului a confirmat preluarea.

**Mesaj procesat:** actorul a finalizat activitatea corespunzătoare.

Acestea sunt evenimente diferite.

Nu trebuie să implementăm imediat un workflow complicat, dar trebuie să evităm pierderea mesajelor dacă un actor se oprește după preluare, înainte de procesare.

### Recomandarea mea privind arhitectura

Aș adopta:

**MCAD Mailbox Storage + Actor Mailbox Client + Sam Communication Rules.**

Nu este nevoie de un broker separat.

MCAD găzduiește și deservește directoarele de comunicare.

Runtime-ul actorului publică și preia mesaje prin SSH.

Sam coordonează protocolul organizațional.

### Ce se întâmplă dacă MCAD nu este disponibil?

Mesajele deja persistate în MCAD rămân acolo.

Actorul poate continua lucrul local, dar nu poate presupune că un mesaj nou a fost livrat.

Dacă dorim funcționare în perioade de indisponibilitate, putem păstra local mesajele în așteptare și le putem publica ulterior.

**Aceasta ar reutiliza persistența Git/locală existentă**, fără să construim o nouă infrastructură.

---

# 8. Arhitectura revizuită

```text
                            HUMAN
                              |
                              v
                    +------------------+
                    |       NIMC       |
                    |                  |
                    | VFS | Actor      |
                    |     | Dialog     |
                    |     | Shell PTY  |
                    +--------+---------+
                             |
                       SSH / local
                             |
                             v
                 +------------------------+
                 |     ACTOR RUNTIME      |
                 |                        |
                 |  Conversation Engine   |
                 |                        |
                 |  AI Model Client ------+------ SSH ------+
                 |                        |                 |
                 |  Knowledge Client -----+--- SSH ---+     |
                 |                        |           |     |
                 |  Mailbox Client -------+--- SSH ---|--+  |
                 |                        |           |  |  |
                 |  Shell / Git / VFS     |           |  |  |
                 |                        |           |  |  |
                 |  Git Persistence       |           |  |  |
                 |                        |           |  |  |
                 |  PID 1 Lifecycle       |           |  |  |
                 +-----------+------------+           |  |  |
                             |                        |  |  |
                      ARTIX CONTAINER                 |  |  |
                             |                        |  |  |
                       NACM / PODMAN                  |  |  |
                                                      |  |  |
                         +----------------------------+  |  |
                         |                               |  |
                         v                               |  v
                       CMS                               | MCAD
                  Jordy / Spok                           |  |
                                                         |  +-- Models
                                                         |  +-- Identity
                                                         |  +-- Accounting
                                                         |  +-- Mailbox
                                                         |
                                                         +-- Team Mailbox
```

*Legăturile reprezintă interfețe logice, nu o topologie de rețea obligatorie.*

Pentru instalarea pe un singur calculator, putem utiliza aceleași interfețe prin SSH și optimiza ulterior anumite legături prin socket Unix.

---

# 9. Revizuirea responsabilităților

| Funcție | MCA | MCAD | Runtime | NACM |
|---|---|---|---|---|
| Configurație actor | **Da** | Citește | Utilizează | — |
| Identitate și Passport | **Autoritate** | Verifică | Se autentifică | Configurează UID |
| Containere | — | — | — | **Da** |
| Motor conversațional | — | — | **Da** | — |
| Acces model AI | Aprobă | **Furnizează** | Solicită | — |
| Contabilizare consum | Politici | **Da** | — | — |
| Context Git personal | — | — | **Da** | Persistența volumului |
| Conversații Markdown | — | — | **Da** | — |
| Push Forgejo | — | — | **Da** | — |
| Shell și procese copil | — | — | **Da** | Configurează limitele |
| VFS | — | — | **Da** | Configurează montările |
| Dialog Human | — | — | **Da** | — |
| Interfața NIMC | — | — | Client extern | — |
| Mailbox central | Politici generale | **Da** | Client | — |
| Acces CMS | — | — | Client | — |
| Funcții PID 1 | — | — | **Da** | — |
| Comunicații SSH | Configurare identități | Endpoint de servicii | Client/server, după necesitate | Rețea/izolare |

CMS, Jordy, Spok și Sam rămân componente cu responsabilități distincte, chiar dacă nu apar ca administratori în acest tabel.

---

# 10. Întrebările rămase pentru motorul conversațional

Nu intru încă în detalierea punctului 10, deoarece ai precizat că îl vei dezvolta separat.

Aș păstra însă următoarele întrebări, completate cu cele rezultate din noile decizii:

**A. Reprezentarea conversației**

Folosim Markdown drept format canonic sau păstrăm evenimente structurate din care generăm Markdown?

Aici trebuie să ținem cont de istoricul conversației, apelurile de instrumente și recuperarea după întrerupere.

**B. Organizarea discuțiilor**

Cum identificăm proiectul, actorul Human și conversația curentă? Cum gestionăm mai multe discuții cu același Human, fără să confundăm istoricul lor?

**C. Persistența**

Când salvăm mesajele, când facem commit și când publicăm în Forgejo? Cum evităm pierderea unui răspuns în curs de generare?

**D. Protocolul NIMC–runtime**

Ce mesaje sunt necesare pentru prompt, streaming, întrerupere, istoric, atașamente și artefacte?

**E. Execuția instrumentelor**

Cum reprezentăm apelurile modelului către shell/VFS și cum întoarcem rezultatele? Cum distingem rezultatele comenzilor de textul conversației?

**F. Recuperarea după restart**

Cum reia actorul o conversație sau o sarcină întreruptă? Ce informații trebuie să existe în Git și ce poate fi reconstruit?

**G. Comunicațiile distribuite**

Cum funcționează interfața de dialog și transferurile de fișiere când NIMC și containerul actorului se află pe hosturi diferite?

---

## Concluzie — arhitectura actualizată

Din ultimele clarificări rezultă o împărțire simplă:

**NACM/Podman** gestionează containerul.

**Linux** furnizează procesele, shell-ul, filesystem-ul și mecanismele de securitate.

**Actor Runtime** furnizează motorul conversațional, instrumentele, accesul la cunoaștere, persistența Git și lifecycle-ul PID 1.

**MCAD** furnizează identitate verificată, acces la modele, contabilizarea consumului și infrastructura centrală de mailbox.

**CMS/Jordy/Spok** furnizează accesul la cunoaștere.

**NIMC** oferă Human o interfață unificată de dialog, shell și VFS.

**Forgejo** asigură publicarea și sincronizarea repository-urilor Git.

Arhitectura poate funcționa pe un singur host sau distribuită, cu SSH drept transport comun.

### Recomandarea mea

Aș păstra **mailbox-ul centralizat în MCAD**, deoarece simplifică identificarea expeditorilor, persistarea mesajelor și comunicarea între actori aflați pe hosturi diferite.

Dar nu aș transforma MCAD într-un orchestrator al conversațiilor. El transportă și persistă mesajele; **Actor Runtime rămâne responsabil pentru interpretarea și procesarea lor**.

Avem acum un cadru suficient de clar pentru a detalia punctul 10: **motorul conversațional și contractul dintre Human, Actor Runtime și modelul AI**.

------------------------>

Da, sa incepem: 1. Da formatul markdown are multe avantaje (afisare/editare/interpretare). Formatul json trebuie sa fie unul intern (intermediar) strict operational (utilizat numai daca aduce avantaje si simplifica codul necesar) sau destinat stocarii unor informatii in baze de date (de tip sqlite) daca este nevoie. Putem considera utilizarea in fisierele .md a unor referinte (sau URL-uri) catre fisiere externe media sau de alta natura.  In fisierele .md putem adauga metadate dupa nevoie (de exemplu pentru fisierele .ms din mailbox sau din repo Git personal al actorului). Doar cerul este limita aici. Adaugam ceva nou in masura in care este necesar.  2. Aici e destul de clar.  3. Si aici e clar.  4. De fapt shellul PTY ocupa jumatatea inferioara  ecranului. Insa ideea este aceeasi, 3 spatii de lucru simultane la dispozitia utilizatorului, exact asa cum am dorit dintotdeauna (de fapt erau 2 inainte de AI VFS si Sghell PTY. Acum s-a adaugat si pane special pentru dialog AI).  5. E clar.  6. Mai trebuie adaugata o legatura SSH intre NIMC si MCAD. (accesul la CMS se face prin bibliotecar sau prin SPOK asa ca SSH catre runtime -actor deserveste necesitatea).   7. Fisierele temporare (sau cele netransmise) sunt stocate local in containerul actorului repectiv. Daca MCAD nu e disponibil temporar, oricum suportul echipei si accesul la modelele AI nu este disponibil (aici o sa putem optimiza in viitor pentru modele AI locale pe acelasi host sau in reteaua locala si separat pentru cele remote (cu/fara costuri de utilizare). In principiu actorul poate pastra un mic cache (cu dimensiunea maxima setata prin configurarea actorului) cu continutul temporar pe care il foloseste la lucrul curent, incluzind comunicatia.   8. este destul de clar.  9. clar si aici . O sa detaliez punctul 10 mai incolo. Clar pina aici? Intrebari si/sau propuneri suplimentare?

Nim --->
Da. **Arhitectura este clară până aici și consider că putem păstra aceste decizii ca bază pentru detalierea motorului conversațional.** Nu văd necesitatea unor modificări structurale.

Aș face doar câteva precizări și trei propuneri punctuale.

## 1. Deciziile consolidate

| Domeniu | Decizie |
|---|---|
| Format conversații | **Markdown canonic**, lizibil și editabil |
| JSON | Exclusiv operațional, când simplifică implementarea |
| Metadate | Adăugate în Markdown pe măsura necesităților |
| Fișiere externe | Referințe relative sau URL-uri din Markdown |
| Istoric conversații | Repository Git personal al actorului, organizat pe proiecte și interlocutori |
| Persistență Git | Locală, cu publicare ulterioară în Forgejo |
| NIMC | Trei spații simultane: VFS, Actor Dialog și Shell PTY |
| Shell PTY | Ocupă **jumătatea inferioară a ecranului** |
| Comunicații | SSH între componente, inclusiv **NIMC ↔ MCAD** |
| Acces cunoaștere | Runtime ↔ Jordy/Spok prin SSH |
| Mailbox | Centralizat în MCAD |
| Fișiere temporare | Stocate local în containerul actorului |
| Cache de lucru | Local, cu limită configurabilă |
| Indisponibilitate MCAD | Actorul păstrează datele locale; serviciile centrale nu sunt disponibile |
| Modele locale | Posibilitate de optimizare ulterioară |

Un principiu important este că **formatul Markdown nu trebuie transformat într-un protocol complicat**. Începem cu text, metadate minimale și referințe la fișiere. Adăugăm structură numai când apare o necesitate concretă.

## 2. NIMC — dispunerea corectată

Schema corespunzătoare descrierii tale este:

```text
┌─────────────────────────────────────────────────────┐
│                       NIMC                          │
├─────────────────────────┬───────────────────────────┤
│                         │                           │
│                         │                           │
│          VFS            │       ACTOR DIALOG        │
│                         │                           │
│                         │                           │
├─────────────────────────┴───────────────────────────┤
│                                                     │
│                      SHELL PTY                      │
│                                                     │
│                                                     │
├─────────────────────────────────────────────────────┤
│                    STATUS BAR                       │
└─────────────────────────────────────────────────────┘
```

Această organizare păstrează modelul existent NIMC și adaugă Actor Dialog fără să înlocuiască funcționalitatea Shell PTY.

Mai important, utilizatorul poate transfera text și fișiere între cele trei spații, utilizând mecanismele deja dezvoltate.

**Actor Dialog va fi un client al runtime-ului, nu o implementare separată a motorului conversațional.**

## 3. Comunicații — cele două legături NIMC

Confirm necesitatea ambelor conexiuni:

```text
                       NIMC
                        │
                ┌───────┴────────┐
                │                │
               SSH              SSH
                │                │
                ▼                ▼
          Actor Runtime         MCAD
                │                │
                │                ├── Identity
                │                ├── Model Services
                │                └── Mailbox
                │
                ├── SSH ──> CMS / Jordy / Spok
                │
                └── SSH ──> Forgejo
```

Cele două legături au responsabilități diferite.

**NIMC ↔ Actor Runtime** deservește dialogul interactiv, istoricul conversațiilor și transferul fișierelor.

**NIMC ↔ MCAD** deservește funcțiile centrale la care Human are drept de acces. Vom defini ulterior comenzile și serviciile disponibile prin această legătură.

Nu aș face MCAD intermediar obligatoriu pentru dialogul NIMC–Actor. Ar introduce o dependență suplimentară fără beneficiu demonstrat.

Totuși, actorul are în continuare nevoie de MCAD pentru accesul la modelul AI autorizat.

---

# 4. Propuneri suplimentare

Am trei propuneri care nu schimbă arhitectura.

### A. Referințe relative pentru fișierele conversației

Pentru fișierele aflate în repository-ul Git al actorului, recomand utilizarea cu prioritate a căilor relative.

Exemplu:

```markdown
**Human:** Analizează jurnalul atașat.

[Fișier primit](Received/mcad-test-20261118-124500.log)

**Actor:** Am pregătit raportul.

[Raport rezultat](Sent/mcad-report-20261118-125000.md)
```

Avantajul este portabilitatea.

Dacă repository-ul este clonat pe alt host sau în alt container, referințele relative continuă să funcționeze.

URL-urile sunt potrivite pentru resursele externe.

### B. Separarea cache-ului temporar de datele persistente

Aici aș face o distincție simplă.

| Tip de date | Comportament |
|---|---|
| Conversații și fișiere confirmate | Persistente, în Git |
| Mesaje pregătite, dar netransmise | Persistente local până la confirmarea livrării |
| Rezultate intermediare regenerabile | Cache temporar |
| Fișiere de lucru curente | Workspace local |
| Istoric consolidat | Git / CMS |

**Nu aș pune mesajele netransmise într-un cache care poate fi eliminat automat.**

Cache-ul poate avea o limită maximă configurabilă și poate fi curățat când este nevoie.

Dar un mesaj deja pregătit pentru expediere nu trebuie să dispară doar fiindcă s-a atins limita cache-ului.

Putem utiliza directoare distincte în același volum persistent, fără un nou serviciu.

### C. Publicarea Git și livrarea mesajelor trebuie să fie independente

Un mesaj transmis către MCAD și un commit publicat în Forgejo sunt două operații diferite.

De exemplu:

1. Actorul finalizează un mesaj.
2. Îl salvează local.
3. Îl transmite către MCAD.
4. Primește confirmarea de persistență.
5. Marchează local mesajul ca livrat.
6. Ulterior, face `git push` către Forgejo.

Nu trebuie să așteptăm disponibilitatea Forgejo pentru comunicarea prin mailbox.

Invers, un `git push` reușit nu înseamnă că destinatarul a primit mesajul.

Această delimitare este importantă pentru instalarea distribuită.

---

## 5. O singură întrebare arhitecturală pentru mai târziu

Există un aspect pe care nu trebuie să îl rezolvăm acum, dar care va conta la definirea protocolului conversațional:

**Cum gestionăm două interfețe Human conectate simultan la același actor?**

De exemplu, NIMC poate fi deschis pe două calculatoare diferite.

Putem permite conversații independente, fiecare cu propriul identificator, fără să amestecăm mesajele. Trebuie însă stabilit ulterior cum coordonăm operațiile atunci când ambele conversații solicită modificarea acelorași fișiere.

Nu propun un manager nou de sesiuni. Este suficient să păstrăm această situație în vedere.

---

## 6. Starea arhitecturii

```text
MCA_ACTOR_RUNTIME_ARCHITECTURE

CONTAINER:
  MANAGEMENT=NACM_PODMAN
  OS=ARTIX_LINUX

ACTOR_RUNTIME:
  CONVERSATION_ENGINE=YES
  CONVERSATION_STORAGE=MARKDOWN_GIT
  MODEL_ACCESS=MCAD
  KNOWLEDGE_ACCESS=SSH_JORDY_SPOK
  SHELL_TOOLS=LINUX
  LOCAL_FILES=VFS
  LIFECYCLE=PID1

NIMC:
  VFS=UPPER_LEFT
  ACTOR_DIALOG=UPPER_RIGHT
  SHELL_PTY=LOWER_HALF
  RUNTIME_CONNECTION=SSH
  MCAD_CONNECTION=SSH

PERSISTENCE:
  PERSONAL_REPOSITORY=LOCAL_GIT
  REMOTE_REPOSITORY=FORGEJO
  FILE_ATTACHMENTS=SENT_RECEIVED
  CACHE=LOCAL_BOUNDED
  UNSENT_MESSAGES=PERSISTENT

COMMUNICATION:
  TEAM_MAILBOX=MCAD
  TRANSPORT=SSH
  SAME_HOST_OPTIMIZATION=UNIX_SOCKET_OPTIONAL

STATUS=CONCEPTUAL_ARCHITECTURE
```

### Concluzie

**Nu consider necesar să mai adăugăm subsisteme în acest moment.**

Avem o arhitectură care poate funcționa atât pe un singur calculator, cât și distribuit, fără să duplicăm funcțiile Linux, Git, OpenSSH sau Podman.

Cele trei propuneri privind referințele relative, separarea cache-ului și independența livrării mesajelor față de Git sunt suficiente pentru etapa actuală.

Putem păstra punctul 10 pentru discuția separată, așa cum ai propus.

---------------------->

O sa detaliez doar punctele ce necesita asta: 3. Da, actorii umani ar putea contacta direct actorul sau prin Sam (va depinde de setarile din mca. La modelul ierarhic de organizare al echipei fiecare actor uman poate avea setari care permit contactarea directa a unui grup mai restrins de actori AI).  4. A. De acord  B. Aici trebuie gindit/optimizat un model de cache potrivit. Pentru mesajele netrimise se poate crea un director (Waiting - de exemplu) pe calculatorul unde este instalat mcad si mesajul se copie acolo, urmind sa fie procesat cind mcad este din nou functional.  Trebuie doar sa ne gindim cum ar functiona in modul-manual din practica.  C. Mailbox-ul este gestonat de secretariat/Sam - o sa detaliez cu Sam cum se va rezolva.  5. Buna intrebare. Asta ma intreb si eu. Sa ne gindim la o abrdare in mod-manual. Daca o comparam cu o conversatie la telefon, atunci e simplu. Primul actor uman care "stabileste conversatia are prioritate", pentru celalalt/ceilalti actorul AI respectiv "este ocupat". Si putem seta si un timeout rezonabil de inchidere a conexiunii interfetei (S-ar afisa in fereastra dialogului cu actorul Ocupat/Disponibil). E o rezolvare simpla nu cea mai potrivita.  Insa in cazul nostru e o solutie mult mai buna. Interfetele umane se conecteaza la un actor pentru un proiect al sau (sau unicul proiect al sau) sau numai la actorul respectiv (in cazul in care actorul nu are un proiect asignat sau discutia este generala nu axata pe un proiect anume). Fiecare actor apelant are un director pentru conversatia respectiva, asa ca fisierele din continut nu sa amesteca/suprascriu la destinatie. Si atunci implementam un "inel de conversatie" asemanator protocolului token-ring de retea pentru deservire in timp real, multiuser a dialogurilor cu multipli actori.   Acum te rog sa redefinesti intrebarile de la punctul 10 sa le dezbatem mai departe (divide et impera).

Nim --->
# MCA / Actor Runtime — Punctul 10
## Redefinirea întrebărilor pentru proiectarea motorului conversațional
**18 noiembrie 2026**

Propun să aplicăm metoda **Divide et Impera**: împărțim motorul conversațional în probleme funcționale mici, stabilim comportamentul dorit prin analogie cu lucrul manual și abia apoi alegem mecanismele Linux și structurile de date necesare.

Nu vom transforma fiecare problemă într-un subsistem software separat.

## 1. Clarificări arhitecturale acceptate

Înainte de redefinirea întrebărilor, rețin patru decizii importante.

**A. Accesul Human–Actor**

Un actor uman poate contacta actorul AI direct sau prin Sam, conform configurației și drepturilor stabilite în MCA.

Într-o echipă ierarhică, accesul direct poate fi limitat la anumite categorii de actori AI.

MCAD verifică autoritatea pentru serviciile și conexiunile pe care le deservește, fără să modifice organizarea echipei.

**B. Mailbox-ul**

Responsabilitatea organizațională aparține lui Sam. Nu stabilim acum structura definitivă sau mecanismele de livrare.

Directorul `Waiting` rămâne o posibilitate de analizat.

Există o precizare practică: dacă MCAD este complet indisponibil, actorul de pe alt host nu poate copia direct un mesaj într-un director accesibil numai prin MCAD. Pentru acest caz va trebui să diferențiem indisponibilitatea procesului MCAD de indisponibilitatea întregului host sau a accesului SSH.

Nu este necesar să rezolvăm problema acum.

**C. Conversații separate**

Fiecare interlocutor Human are propriul spațiu de conversație, în cadrul proiectului corespunzător sau în contextul general al actorului.

Astfel, mesajele și fișierele interlocutorilor nu se amestecă.

**D. Inelul de conversație**

Propunerea de a utiliza un mecanism inspirat de **token-ring** este interesantă deoarece separă două probleme:

- păstrarea simultană a mai multor conversații;
- acordarea timpului de procesare pentru fiecare conversație.

Nu este necesar să blocăm complet un actor pentru un singur interlocutor.

Totuși, nu aș implementa literalmente protocolul token-ring. Aș prelua principiul **deservirii echitabile prin rotație**, folosind o coadă simplă de conversații active.

Acest lucru poate permite ca un actor să deservească mai mulți interlocutori fără să fie necesare mai multe instanțe ale motorului AI.

---

# 2. Punctul 10 — Noua împărțire

Propun **șapte teme**, în ordinea dependențelor dintre ele.

| Etapă | Temă | Întrebarea principală |
|---|---|---|
| **10.1** | Modelul conversației | Ce este o conversație și cum o identificăm? |
| **10.2** | Motorul AI | Cum transformăm mesajele în răspunsuri și acțiuni? |
| **10.3** | Contextul și memoria | Ce informații furnizăm modelului și cum le selectăm? |
| **10.4** | Persistența Markdown/Git | Cum salvăm și recuperăm conversațiile? |
| **10.5** | Concurență și inelul conversațiilor | Cum deservim mai mulți interlocutori? |
| **10.6** | Interfețe și transport | Cum conectăm NIMC, MCAD și actorii Human? |
| **10.7** | Continuitate și recuperare | Cum funcționăm la întreruperi și reporniri? |

Fiecare temă va produce un contract funcțional minimal.

Nu vom scrie cod până când comportamentul de bază nu este suficient de clar.

---

# 3. Întrebările detaliate

## 10.1. Modelul conversației

**Obiectiv:** definim unitatea fundamentală de interacțiune.

Întrebări:

1. Ce reprezintă o conversație: un dialog continuu cu un interlocutor sau o succesiune de discuții distincte?
2. Cum identificăm conversația prin actor, Human și proiect?
3. Cum reprezentăm discuțiile generale, care nu aparțin unui proiect?
4. Cum diferențiem un mesaj Human, un răspuns AI și rezultatul unui instrument?
5. Cum asociem fișierele Sent/Received cu mesajele corespunzătoare?
6. Cum păstrăm ordinea mesajelor și referințele dintre ele?
7. Ce metadate sunt necesare inițial și ce putem introduce ulterior?

**Propunere inițială:** o conversație are un identificator stabil și aparține unui context `(actor AI, interlocutor Human, proiect opțional)`.

Fișierele Markdown pot fi împărțite periodic, fără să schimbe identitatea logică a conversației.

---

## 10.2. Motorul AI

**Obiectiv:** definim ciclul efectiv de lucru al actorului.

Întrebări:

1. Cum primește runtime-ul o solicitare?
2. Cum construiește cererea către model?
3. Cum selectează modelul aprobat prin MCAD?
4. Cum procesează răspunsurile modelului?
5. Cum transmite streaming către interlocutor?
6. Cum recunoaște solicitările de executare a instrumentelor?
7. Cum execută o comandă Linux și transmite rezultatul înapoi modelului?
8. Cum decide că răspunsul este complet?
9. Cum tratăm întreruperea voluntară a unei generări?
10. Cum gestionăm erorile modelului sau ale instrumentelor?

**Propunere inițială:** un singur motor AI cu un ciclu simplu:

```text
Mesaj
  |
Context
  |
Model AI
  |
  +-- Răspuns final
  |
  +-- Tool Call
         |
       Linux
         |
       Rezultat
         |
       Model AI
```

Motorul aparține runtime-ului, nu MCAD.

---

## 10.3. Contextul și memoria

**Obiectiv:** stabilim ce știe actorul la fiecare apel al modelului.

Întrebări:

1. Ce informații din personalitatea actorului sunt prezente permanent?
2. Ce informații din proiect sunt necesare?
3. Cât din istoricul conversației este inclus?
4. Cum căutăm informații în repository-urile Git?
5. Când solicităm informații suplimentare de la Jordy sau Spok?
6. Cum tratăm documentele și fișierele atașate?
7. Cum evităm depășirea ferestrei de context a modelului?
8. Cum extragem experiență utilă dintr-o conversație?
9. Ce diferență există între contextul temporar și experiența persistentă?

**Propunere inițială:** actorul folosește contextul local disponibil, iar căutarea extinsă este solicitată numai când este necesară.

Nu încărcăm automat întregul repository personal sau CMS în contextul modelului.

---

## 10.4. Persistența Markdown/Git

**Obiectiv:** stabilim cum păstrăm informațiile.

Întrebări:

1. Care este formatul minimal al unui mesaj Markdown?
2. Cum grupăm conversațiile în fișiere pe intervale de timp?
3. Când persistăm un mesaj primit?
4. Când persistăm un răspuns aflat în curs de generare?
5. Cum tratăm fișierele trimise și recepționate?
6. Când realizăm commituri Git?
7. Când sincronizăm cu Forgejo?
8. Cum tratăm editarea manuală a conversațiilor?
9. Cum păstrăm proveniența și legăturile către fișiere externe?

**Propunere inițială:** Markdown este sursa canonică. Git oferă versiuni și sincronizare, fără a fi necesar pentru fiecare operație de salvare.

---

# 4. Concurența — tema nouă și importantă

## 10.5. Inelul conversațiilor

**Obiectiv:** un actor AI poate deservi mai multe conversații, fără să le amestece.

Exemplu:

```text
                 ACTOR AI
                    |
             Conversation Ring
                    |
          +---------+---------+
          |         |         |
          v         v         v
       Human A   Human B   Human C
          |         |         |
       Proiect X Proiect Y  General
```

Modelul nu trebuie să genereze simultan trei răspunsuri pentru a deservi trei interlocutori.

Putem avea o singură execuție activă și mai multe conversații în așteptare.

### Întrebări de stabilit

1. Câte conversații pot rămâne deschise simultan?
2. Ce înseamnă că o conversație este activă?
3. Când primește o conversație dreptul de procesare?
4. Cât timp poate păstra acest drept?
5. Ce se întâmplă când modelul execută un apel lung?
6. Cum anunțăm interlocutorii că așteaptă?
7. Cum prevenim monopolizarea actorului de către o singură conversație?
8. Cum tratăm intervențiile Human cu prioritate administrativă?
9. Cum persistăm ordinea conversațiilor la restart?
10. Cum evităm accesul simultan conflictual la aceleași fișiere?

### Două modele posibile

**Modelul A — Conversație exclusivă**

Primul Human conectat primește actorul.

Ceilalți văd `OCUPAT`.

Este foarte simplu, dar poate bloca inutil alte conversații.

**Modelul B — Inel de conversație**

Mai mulți interlocutori pot avea conversații deschise.

Runtime-ul le deservește succesiv, după o ordine configurabilă.

Acest model este mai flexibil.

**Recomand modelul B**, dar implementat printr-o coadă circulară simplă, nu printr-un protocol distribuit de token.

### O observație importantă

Trebuie să distingem între două tipuri de concurență:

**Concurența conversațională:** mai mulți Human solicită răspunsuri.

**Concurența operațională:** două sarcini încearcă să modifice aceleași fișiere.

Inelul de conversație poate rezolva prima problemă, dar nu garantează automat absența conflictelor asupra fișierelor.

Pentru acestea folosim, în primul rând, mecanismele Linux și Git existente.

---

## 10.6. Interfețe și transport

**Obiectiv:** motorul conversațional poate funcționa independent de NIMC și de amplasarea componentelor.

Întrebări:

1. Care este contractul minimal NIMC–Actor Runtime?
2. Cum transmitem prompturi și mesaje?
3. Cum transmitem streaming-ul răspunsului?
4. Cum transmitem starea `DISPONIBIL`, `OCUPAT` sau `ÎN AȘTEPTARE`?
5. Cum întrerupem o generare?
6. Cum transmitem fișierele Sent/Received?
7. Cum recuperăm istoricul conversației?
8. Cum funcționează toate acestea prin SSH?
9. Ce responsabilități are conexiunea separată NIMC–MCAD?
10. Cum schimbăm ulterior SSH cu socket Unix pe același host fără să modificăm motorul?

**Propunere inițială:** un contract de mesaje și evenimente independent de interfața vizuală, transportat inițial prin SSH.

Nu avem nevoie de un server Web propriu în runtime pentru prima versiune.

---

## 10.7. Continuitate și recuperare

**Obiectiv:** actorul își poate continua activitatea după întreruperi.

Întrebări:

1. Ce se întâmplă dacă NIMC se închide în timpul generării?
2. Ce se întâmplă dacă legătura SSH se întrerupe?
3. Ce se întâmplă dacă MCAD devine indisponibil?
4. Cum salvăm un răspuns parțial?
5. Cum recuperăm o conversație după repornirea containerului?
6. Cum reluăm mesajele din Waiting?
7. Cum evităm retrimiterea duplicată?
8. Cum tratăm operațiile Git neterminate?
9. Cum recuperăm o sarcină întreruptă fără să repetăm necontrolat efectele sale?
10. Ce date rămân exclusiv în cache și ce date trebuie obligatoriu persistate?

**Propunere inițială:** recuperăm întâi informația confirmată și evităm reluarea automată a operațiilor cu efecte atunci când rezultatul lor este incert.

---

# 5. Ordinea recomandată a discuției

Aș modifica ușor ordinea implementării față de ordinea analizei.

**Pentru discuție:**

```text
10.1  Modelul conversației
          |
          v
10.2  Motorul AI
          |
          v
10.3  Contextul și memoria
          |
          v
10.4  Markdown/Git
          |
          v
10.5  Conversation Ring
          |
          v
10.6  NIMC / SSH
          |
          v
10.7  Recuperare
```

**Pentru implementare**, vom putea combina ulterior mai multe teme într-o singură schimbare funcțională. Nu trebuie să avem șapte etape de dezvoltare separate.

---

## 6. Două principii suplimentare

### Un actor AI nu înseamnă un singur apel la model

Un actor poate avea multe conversații deschise, chiar dacă execută numai o inferență la un moment dat.

Prin urmare, identitatea actorului, identitatea conversației și execuția unei cereri către model sunt lucruri distincte.

Această separare ne permite să implementăm inelul conversațiilor fără să multiplicăm procesele runtime.

### Prioritatea de procesare nu înseamnă proprietatea conversației

În mecanismul inspirat de token-ring, „tokenul” trebuie interpretat ca **drept temporar de procesare**, nu ca drept de proprietate asupra actorului.

Fiecare Human își păstrează propriul context și propriul istoric.

Când actorul trece la altă conversație, schimbă contextul de lucru, nu identitatea.

---

# 7. Propunerea pentru începutul dezbaterii

Aș începe cu **10.1 — Modelul conversației**, dar limitat la trei decizii fundamentale:

**10.1/A — Identitatea conversației**

O conversație aparține unui actor AI, unui interlocutor Human și unui proiect opțional.

**10.1/B — Structura conversației**

Conversația este o succesiune ordonată de mesaje și evenimente, păstrată în Markdown.

**10.1/C — Durata conversației**

O conversație poate continua pe termen lung; fișierele Markdown sunt împărțite periodic, fără să îi schimbe identitatea.

Aceste trei decizii vor constitui fundamentul pentru motorul AI, persistența Git și inelul conversațiilor.

**Recomand să discutăm întâi 10.1/A–C și să stabilim contractul minimal al conversației, înainte de a defini mecanismul de procesare multiuser.*

---------------------->

Bine. Pentru 1. D. Modelul token-ring era o metafora pentru a explica principiul de functionare. Da, o coada circulara poate fi folosita in care se adauga indicatorii discutiilor simultane si care are un "token" indicind cine are cuvintul la un moment dat (la fel ca la discutiile multivers). Acum faimosul punct 10.  ->  10.1  1. O serie de discutii distincte. O discutire distincta poate cuprinde una sau mai multe conversatii. Acele conversatii sunt echivalente cu discutiile pe proiect din chatGPT web (care au una sau mai multe conversatii in ele).  2. Mai degraba prin Human-Actor-Proiect.  3. Human-Actor-data ar fi plasate in directorul root al conversatiilor coresounzatoare.  4. Cu metadate plasate in locatia de inceput (sau ceva asemanator tag-urilor.parantezelor din formatul html (metafora).  5. Referinte locale sau URL-uri (dupa caz) in fisierul .md al conversatiei.  6. Dupa timpul la care au avut loc. Pentru fiecare cerere/raspuns din conversatie, la inceput este plasata data si ora la care au avut loc.   7. Aplicam metoda noastra. La inceput timpul si tipul de text (cerere/raspuns/output...) Apoi adaugam alte tipuri de metadate dupa cum avem nevoie.   O sa continui cu 10.2 la urmatorul prompt. Asa le pastram distinct.

Nim --->
# MCA / Actor Runtime — 10.1
## Modelul conversației — consolidarea deciziilor
**18 noiembrie 2026**

**Status: `10.1 ACCEPTAT CONCEPTUAL`**

Am înțeles clarificările. Le consider coerente cu arhitectura stabilită și nu propun modificări majore.

### 1. Ierarhia conversațională

Distincția importantă este între **discuție** și **conversație**.

O discuție distinctă poate conține una sau mai multe conversații, asemenea organizării discuțiilor dintr-un proiect ChatGPT Web.

Identificarea se face în ordinea:

**Human → Actor AI → Proiect → Discuție → Conversație**

Pentru dialogurile generale, fără proiect asignat, identificarea se face prin **Human → Actor AI → Data discuției**, iar fișierele sunt plasate în directorul rădăcină al conversațiilor.

Aceasta este structura logică. Nu impune încă o ierarhie suplimentară de directoare.

### 2. Reprezentarea mesajelor

Markdown rămâne formatul canonic.

Fiecare cerere, răspuns sau rezultat al unui instrument conține inițial doar două metadate obligatorii:

- **Data și ora** evenimentului.
- **Tipul conținutului:** cerere, răspuns, output etc.

Metadatele vor apărea la începutul blocului corespunzător, folosind o convenție simplă, inspirată eventual de marcajele HTML.

Ordinea cronologică este dată de marcajele temporale.

Pentru situațiile în care două evenimente au același timestamp, ordinea fizică din document poate fi păstrată ca ordine de înregistrare.

### 3. Fișiere și artefacte

Fișierele Markdown vor conține referințe către materialele asociate:

- Căi relative pentru fișierele locale.
- URL-uri pentru resurse externe.

Fișierele transferate rămân în `Sent/` și `Received/`, fără subdirectoare suplimentare, cu timestamp în nume.

Această organizare permite afișarea, editarea și recuperarea informațiilor fără un format binar propriu.

### 4. Deservirea conversațiilor simultane

Rețin că **token-ring este o metaforă pentru mecanismul de acordare a cuvântului**.

Implementarea poate utiliza o coadă circulară care conține referințe la discuțiile active. Indicatorul curent arată conversația deservită în acel moment.

Nu implementăm un protocol de rețea token-ring și nici nu introducem un proces separat pentru fiecare conversație.

Vom detalia această funcționalitate la punctul **10.5 — Concurență conversațională**.

### 5. Exemplu minimal de reprezentare

Fără să stabilim prematur sintaxa finală, un document ar putea arăta astfel:

```markdown
# Discuție MCA — Actor Runtime

<!-- 2026-11-18 14:10 | request -->
Trebuie să clarificăm modelul conversațional.

<!-- 2026-11-18 14:11 | response -->
Modelul conversațional utilizează Markdown
și păstrează ordinea cronologică.

<!-- 2026-11-18 14:12 | output -->
[Rezultat test](Sent/runtime-test-20261118-141200.log)
```

Este doar o ilustrare. Sintaxa exactă o stabilim când implementarea o va necesita.

### 6. O singură precizare pentru proiectarea ulterioară

**Discuția, conversația și fișierul Markdown nu trebuie considerate obligatoriu același obiect.**

O discuție poate cuprinde mai multe conversații, iar istoricul unei conversații poate fi împărțit în mai multe fișiere Markdown, de exemplu lunar.

Această separare ne permite să organizăm informațiile fără să modificăm modelul logic.

---

## Checkpoint 10.1

```text
ACTOR_RUNTIME_CONVERSATION_MODEL

DISCUSSION:
  CONTAINS=ONE_OR_MORE_CONVERSATIONS

IDENTIFICATION:
  ORDER=HUMAN_ACTOR_PROJECT
  GENERAL=HUMAN_ACTOR_DATE

STORAGE:
  FORMAT=MARKDOWN
  METADATA=TIME_AND_CONTENT_TYPE
  FILE_REFERENCES=RELATIVE_PATH_OR_URL
  MESSAGE_ORDER=CHRONOLOGICAL
  EXTENSIBILITY=AS_NEEDED

CONCURRENCY:
  MODEL=CIRCULAR_CONVERSATION_QUEUE
  TOKEN=PROCESSING_TURN
  DETAILS=DEFERRED_TO_10_5

STATUS=CONCEPTUALLY_ACCEPTED
```

**10.1 este suficient de clar pentru a continua.** Nu văd întrebări suplimentare care să necesite o decizie acum.

Următorul subiect rămâne **10.2 — Motorul AI**, conform ordinii stabilite.

------------------------>

0.2  -> 1. In principiu prin interfata de dialog nimc si/sau prin comunicarea din interiorul echipei. Modul de realizare practica necesita clarificari si detalieri.  2. Aici cercetam sertarele si proiectele care implementeaza agenti locali AI. In functie de asta stabilim cum proiectam/implementam. A se vedea si cum se procedeaza in OpenShell.  3. Asta trebuie detaliat. In sertare s-ar putea sa fie raspunsui, Stiu ca avem pe lista de studiu proiecte care implementeaza gateway-uri sau proxy-uri catre multiple modele AI. Acolo sunt raspunsurile de care avem nevoie. 4. Asta tu sa-mi spui. Depinde sub ce forma si in ce mod parvin acele raspunsuri.   5. - 6. Trebuie studiate sertarele si proiectele care implementeaza asa ceva.  7. in proces child shell cu capturarea outputului.  8.  - 10.  de identificat in sertare si proiecte practice urmarite.    Eu spun ca inainte de a continua sa faci o cercetare amanuntita a sertarelor si a proiectelor urmarite (sunt multe. Putem solicita o lista de la Sam). Si dupa ce identifici rapunsuri totale sau partiale la intrebarile tale reformuleaza intrebarile cu ce a mai ramas neclarificat. Nu sunt familiarizat cum modul intern de functionare al unui model AI sau al unui proiect pentru rularea unui agent AI local cu legatura la modele AI locale sau remote.

Nim --->
# MCA / Actor Runtime — Cercetare 10.2
## Motoare AI locale, gateway-uri multi-model și execuția instrumentelor
**18 noiembrie 2026**

**Status: `RESEARCH / ARCHITECTURE REVIEW` — fără modificări de cod**

Am început prin inventarul disponibil în Technology Watch, materialele păstrate în sertare, arhiva OpenShell și documentația proiectelor de agenți AI.

Prima constatare este importantă: **nu trebuie să proiectăm motorul conversațional de la zero.** Există implementări care rezolvă deja majoritatea problemelor din 10.2, inclusiv construirea solicitărilor către modele, interpretarea răspunsurilor, streaming-ul, executarea instrumentelor și reluarea conversației.

Pentru MCA trebuie să alegem mecanismele compatibile cu arhitectura noastră, nu să importăm un framework întreg.

## 1. Cele trei categorii de proiecte relevante

Cercetarea trebuie împărțită în trei categorii, deoarece ele rezolvă probleme diferite.

| Categorie | Exemple | Ce putem învăța |
|---|---|---|
| **Motoare de agenți AI** | Qwen Code, OpenCode, Pi, Continue, cecli, Shuvarie | Bucla conversațională, instrumente, istoric, streaming |
| **Gateway-uri și proxy-uri AI** | LiteLLM, CLIProxyAPI, gproxy, 9router, OpenRouter | Alegerea modelului, adaptarea API-urilor, rutare, fallback, contabilizare |
| **Context și continuitate** | LeanCTX, Qwen Memory, AI Memory, Nowledge Mem | Selectarea contextului, recuperare, compactare, istoric |

OpenShell aparține unei categorii parțial diferite: oferă infrastructura de execuție și izolare în care poate rula un agent AI. Nu trebuie confundat cu motorul conversațional al agentului.

**Pentru proiectul nostru, Actor Runtime trebuie studiat în primul rând în raport cu prima categorie, iar MCAD în raport cu a doua.**

Aceasta este deja o delimitare funcțională utilă.

## 2. Proiectele identificate și valoarea lor pentru 10.2

Din materialele recuperate, aș selecta următoarele proiecte pentru cercetarea motorului conversațional.

| Proiect | Ce rezolvă | Relevanță pentru noi |
|---|---|---|
| **Qwen Code** | Agent Core independent de UI, modele, instrumente, sesiuni | **Foarte ridicată** |
| **Pi / pi-mono** | Bibliotecă multi-provider, buclă agent, streaming | **Foarte ridicată** |
| **OpenCode** | Sesiuni, pași AI, evenimente, instrumente, recuperare | **Foarte ridicată** |
| **Runx CLI** | Separarea ModelCaller/ToolExecutor și verificarea apelurilor | **Foarte ridicată** |
| **Continue** | Integrarea unui agent cu interfețe externe și instrumente | Ridicată |
| **OpenAI Agents SDK** | Execuția unei bucle agent, streaming, sesiuni | Ridicată |
| **Shuvarie** | Agent headless, sesiuni, provider abstraction | Ridicată, pe baza sertarelor |
| **cecli / clai** | Runtime, context, istoric și capabilități ale actorului | Ridicată, de aprofundat |
| **LiteLLM** | Gateway multi-model, autorizare, rutare, consum | **Foarte ridicată pentru MCAD** |
| **CLIProxyAPI** | Adaptare între API-uri și provideri AI | **Foarte ridicată pentru MCAD** |
| **LeanCTX** | Selectarea și reducerea contextului | Ridicată pentru 10.3 |
| **OpenShell** | Izolare, acces provider, administrarea proceselor | Referință complementară |

Nu toate au fost auditate la același nivel. Pentru Runx și Qwen Code există în sertare cercetări statice ale unor arhive precise; pentru celelalte am verificat documentație și implementări publice selectate.

### Qwen Code — separarea dintre motor și interfață

Documentația Qwen Code descrie `packages/core` ca motor independent de interfață. Acesta include coordonarea agentului, integrarea modelelor, construcția contextului, instrumentele și sesiunile. Interfețele sunt componente distincte. [GitHub](https://github.com/QwenLM/qwen-code/blob/main/docs/developers/architecture.md?utm_source=chatgpt.com)

Este foarte apropiat de ceea ce dorim pentru Nim:

```text
NIMC
  |
  v
Actor Runtime Core
  |
  +-- Model Client
  +-- Tools
  +-- Context
  +-- Conversation State
```

**Concluzie:** separarea Actor Core de NIMC este confirmată de o implementare practică matură.

### Pi — modelul minimal de agent

Pi este deosebit de interesant deoarece separă biblioteca de comunicare cu modelele (`pi-ai`) de motorul agentului și de aplicația terminal.

Biblioteca `pi-ai` gestionează furnizori diferiți, streaming, apeluri de instrumente și informații despre utilizare. Există inclusiv adaptarea furnizorilor care folosesc API-uri compatibile. [GitHub](https://github.com/fivewillow/badlogic-pi-mono/blob/main/packages/ai/README.md?utm_source=chatgpt.com)

Pentru proiectul nostru, Pi ar putea fi cea mai utilă referință pentru **dimensiunea minimă a unui motor conversațional funcțional**.

Nu avem nevoie să preluăm aplicația terminal sau mecanismele sale de autentificare.

### OpenCode — sesiuni și execuții recuperabile

OpenCode este relevant pentru două probleme:

1. Cum separăm o conversație persistentă de o execuție concretă a modelului.
2. Cum reprezentăm răspunsurile parțiale și apelurile de instrumente.

Specificațiile sale recente disting începutul unui pas, evenimentele de streaming și starea instrumentelor. Recuperarea după întreruperi este explicit limitată: nu promite executarea exact o singură dată a operațiilor externe. [GitHub](https://github.com/anomalyco/opencode/blob/dev/specs/v2/session.md?utm_source=chatgpt.com)

Pentru noi rezultă o regulă simplă:

**O conversație poate fi recuperată fără ca o comandă shell întreruptă să fie reluată automat.**

Aceasta nu cere un mecanism complex de tranzacții.

### Runx CLI — ModelCaller și ToolExecutor

Acesta este unul dintre cele mai valoroase rezultate deja prezente în sertare.

Cercetarea versiunii Runx CLI 0.11.0 consemnează separarea dintre:

- `ModelCaller` — comunicarea cu modelul AI;
- `ToolExecutor` — executarea instrumentelor.

Codul inspectat verifică apelurile de instrumente înainte de execuție, dar această verificare nu echivalează cu autorizarea completă a tuturor efectelor.

Cercetarea este statică; nu avem un test funcțional Runx realizat pe Artix în acest checkpoint. Technology-Watch-proiecte-urmar…

**Pentru Actor Runtime, aceasta este probabil cea mai simplă delimitare internă pe care o putem adopta.**

---

# 3. Cum funcționează efectiv un agent AI

Aici putem răspunde deja unei părți importante din întrebările tale.

Un model AI nu primește pur și simplu un prompt și apoi execută singur programe Linux.

Modelul primește o solicitare care poate conține:

- instrucțiuni;
- istoricul relevant;
- informații de context;
- descrierea instrumentelor disponibile;
- mesajul curent al utilizatorului.

Apoi poate produce fie un răspuns, fie o solicitare de utilizare a unui instrument.

**Instrumentul este executat de aplicația-agent, nu de modelul AI.**

Qwen Code și Continue documentează explicit această separare. [GitHub](https://github.com/QwenLM/qwen-code/blob/main/docs/developers/tools/introduction.md?utm_source=chatgpt.com)

## Exemplu: Human solicită compilarea unui proiect Nim

```text
Human:
  Compilează proiectul și verifică testele.
       |
       v
Actor Runtime:
  Pregătește contextul și instrumentele.
       |
       v
MCAD:
  Apelează modelul autorizat.
       |
       v
Model AI:
  Solicită executarea unui instrument shell.
       |
       v
Actor Runtime:
  Lansează procesul copil în Linux.
       |
       v
Linux:
  Execută compilarea și returnează rezultatul.
       |
       v
Actor Runtime:
  Capturează stdout, stderr și exit status.
       |
       v
MCAD:
  Transmite rezultatul către model.
       |
       v
Model AI:
  Interpretează rezultatul și formulează răspunsul.
       |
       v
Actor Runtime:
  Salvează conversația și livrează răspunsul.
       |
       v
NIMC:
  Afișează rezultatul.
```

Această schemă poate repeta apelul la model de mai multe ori în aceeași sarcină.

De exemplu, modelul poate solicita compilarea, apoi citirea unui jurnal, apoi modificarea unui fișier, urmată de o nouă compilare.

Nu este necesară o instanță nouă a runtime-ului pentru fiecare asemenea pas.

## Ce trebuie implementat efectiv în Nim?

Mai puțin decât ar sugera complexitatea unor frameworkuri de agenți.

Motorul minimal trebuie să știe să:

1. Construiască solicitarea către model.
2. Primească evenimentele răspunsului.
3. Identifice un răspuns final sau un apel către instrument.
4. Execute instrumentul prin mecanismele Linux existente.
5. Returneze rezultatul către model.
6. Încheie interacțiunea și persiste rezultatul.

Aceasta este bucla de bază.

Restul funcționalităților se dezvoltă în jurul ei, în funcție de necesități.

---

# 4. MCAD și gateway-urile multi-model

Aici cercetarea indică o delimitare destul de clară.

## LiteLLM

LiteLLM oferă un gateway capabil să gestioneze modele și provideri diferiți.

Documentația sa descrie:

- selecția modelelor;
- rutare și fallback;
- limitări de utilizare;
- evidența consumului;
- bugete;
- gestionarea credențialelor;
- adaptarea solicitărilor.

Este foarte apropiat de responsabilitățile pe care le-am stabilit pentru MCAD. [GitHub](https://github.com/BerriAI/litellm-docs/blob/main/docs/proxy/architecture.md?utm_source=chatgpt.com)

Un rezultat important este că **modelul solicitat și modelul utilizat efectiv nu trebuie confundate**.

Dacă un provider devine indisponibil, gateway-ul poate selecta altul, dar noua alegere trebuie să respecte drepturile și limitele aplicabile.

Nu recomand copierea mecanismului LiteLLM. Recomand utilizarea lui ca referință pentru contractul MCAD Model Service.

## CLIProxyAPI

CLIProxyAPI rezolvă în special o problemă diferită: compatibilitatea între mai multe API-uri și servicii AI.

Documentația descrie interfețe compatibile cu OpenAI, Claude și Gemini, inclusiv configurații pentru modele și provideri diferiți. [GitHub](https://github.com/router-for-me/CLIProxyAPIDocs/blob/main/docs/en/introduction/what-is-cliproxyapi.md?utm_source=chatgpt.com)

Pentru noi, lecția este:

**Actor Runtime nu trebuie să implementeze separat protocolul fiecărui provider.**

Ar fi mai simplu ca MCAD să prezinte runtime-ului o interfață stabilă și să adapteze solicitările pentru providerul concret.

### Propunere de delimitare

| Actor Runtime | MCAD |
|---|---|
| Formulează solicitarea | Verifică modelul aprobat |
| Trimite contextul | Selectează providerul |
| Declară instrumentele disponibile | Adaptează API-ul providerului |
| Primește evenimente | Normalizează răspunsul |
| Execută instrumentele | Nu execută instrumentele actorului |
| Decide continuarea conversației | Înregistrează consumul și costurile |

Această împărțire este compatibilă cu arhitectura distribuită și cu transportul SSH.

Nu presupune folosirea unei API HTTP directe între runtime și provider.

---

# 5. Ce formă au răspunsurile modelului AI?

Aceasta răspunde direct întrebării **10.2/4**.

În practică, un model poate transmite mai multe tipuri de rezultate.

| Rezultat | Semnificație | Ce face runtime-ul |
|---|---|---|
| Text | Răspuns destinat utilizatorului | Îl afișează în NIMC |
| Text incremental | Fragmente succesive ale răspunsului | Le afișează progresiv |
| Tool call | Solicitare de utilizare a unui instrument | Execută instrumentul corespunzător |
| Date structurate | Rezultat într-un format cerut | Le interpretează |
| Informații de utilizare | Tokeni și alte date raportate | Le transmite către evidența MCAD |
| Eroare | Solicitarea nu a putut fi finalizată | Înregistrează și raportează situația |

O particularitate importantă este **streaming-ul**.

În loc să aștepte întregul răspuns, runtime-ul poate primi fragmente succesive.

De exemplu:

```text
MODEL → MCAD → RUNTIME → NIMC

text_delta: "Am analizat"
text_delta: " proiectul"
text_delta: " și am identificat"
text_delta: " următoarele probleme."

response_completed
```

Acestea sunt evenimente ilustrative, nu un protocol MCA deja stabilit.

Pentru utilizator, rezultatul este un text care apare progresiv în Actor Dialog.

OpenAI Agents SDK documentează explicit evenimentele de streaming și diferența dintre rezultatele intermediare și finalizarea execuției. [GitHub](https://github.com/openai/openai-agents-python/blob/main/docs/streaming.md?utm_source=chatgpt.com)

### Streaming-ul instrumentelor este puțin diferit

Modelul poate genera progresiv și argumentele unui instrument.

În acest caz, runtime-ul nu trebuie să execute comanda înainte de primirea și interpretarea completă a apelului.

Exemplu:

```text
Model:
  tool_call_start
  tool_name: shell
  arguments_fragment: ...
  arguments_completed
  tool_call_completed

Runtime:
  execută instrumentul
  capturează rezultatul
  transmite rezultatul modelului
```

**Afișarea progresivă a textului nu trebuie confundată cu executarea progresivă a unor comenzi incomplete.**

Acest aspect este tratat explicit în implementări precum Pi și OpenCode. [GitHub](https://github.com/fivewillow/badlogic-pi-mono/blob/main/packages/ai/README.md?utm_source=chatgpt.com)

---

# 6. Streaming și interfața NIMC — răspuns pentru 10.2/5

Din cercetare rezultă că nu avem nevoie de un mecanism conversațional special pentru NIMC.

Avem nevoie de **o interfață capabilă să primească evenimentele runtime-ului**.

De exemplu:

```text
Actor Runtime
    |
    +-- response_started
    |
    +-- text_delta
    |
    +-- tool_started
    |
    +-- tool_output
    |
    +-- tool_completed
    |
    +-- text_delta
    |
    +-- response_completed
```

NIMC interpretează aceste evenimente și actualizează Actor Dialog.

Aceeași interfață ar putea funcționa ulterior într-un client CLI sau Web.

Din Qwen Code reiese deja că această separare între interfață și motor este practic realizabilă. [GitHub](https://github.com/QwenLM/qwen-code/blob/main/docs/developers/architecture.md?utm_source=chatgpt.com)

**Recomand să nu construim un motor de streaming propriu.** Runtime-ul trebuie doar să transporte și să interpreteze evenimentele necesare.

Forma exactă a evenimentelor o putem decide când definim contractul NIMC–runtime.

---

# 7. Tool calling — răspuns pentru 10.2/6–7

Aici avem deja aproape toate mecanismele necesare.

Modelul AI trebuie să știe **ce instrumente îi sunt disponibile**.

Pentru început, ar putea fi suficient un catalog foarte mic:

```text
shell
read_file
write_file
```

Acesta este un exemplu de catalog, nu o decizie că trebuie implementate trei executori distincți.

`read_file` și `write_file` pot reutiliza direct operațiile VFS.

`Shell` poate utiliza fundația R2 deja validată.

### Cum este declarat un instrument?

Modelul primește o descriere structurată.

Exemplu conceptual:

```json
{
  "name": "shell",
  "description": "Execută o comandă în mediul Linux al actorului",
  "parameters": {
    "command": "string"
  }
}
```

Modelul poate apoi solicita:

```json
{
  "name": "shell",
  "arguments": {
    "command": "nimble test"
  }
}
```

**Aceste fragmente JSON reprezintă comunicare operațională.** Nu contrazic alegerea Markdown pentru persistența conversațiilor.

Runtime-ul execută comanda printr-un proces copil și colectează rezultatul.

Exemplu:

```text
Command: nimble test
Exit code: 0
stdout: ...
stderr: ...
```

Apoi îl transmite modelului.

În registrul Markdown putem păstra rezultatul într-un bloc de tip `output`, cu referință la jurnalul complet dacă acesta este voluminos.

### Ce ne învață Runx?

Separarea `ModelCaller` / `ToolExecutor` este suficientă pentru a delimita responsabilitățile principale ale motorului AI.

**Modelul propune apelul; runtime-ul îl execută folosind autoritatea Linux existentă a actorului.**

Nu avem nevoie de un mecanism MCA suplimentar de autorizare pentru fiecare comandă.

---

# 8. Când este complet un răspuns? — 10.2/8

Aici există deja un răspuns tehnic.

**Finalizarea unui răspuns nu se deduce din faptul că au sosit câteva fragmente de text.**

Providerul transmite evenimente sau indicatori de finalizare.

Agentul trebuie să distingă între:

- răspuns final;
- solicitare de executare a instrumentelor;
- răspuns întrerupt;
- eroare;
- atingerea unei limite de generare.

Dacă modelul solicită un instrument, ciclul nu este terminat.

Dacă instrumentul se execută, rezultatul trebuie transmis înapoi modelului, care poate continua.

În OpenAI Agents SDK, această funcționalitate este gestionată de Runner. [GitHub](https://github.com/openai/openai-agents-python/blob/main/docs/running_agents.md?utm_source=chatgpt.com)

Pentru Nim putem implementa aceeași logică într-o buclă mult mai mică.

### Propunere

Runtime-ul trebuie să știe dacă o interacțiune s-a încheiat cu:

```text
COMPLETED
INTERRUPTED
FAILED
```

Acestea descriu rezultatul interacțiunii, nu starea generală a actorului.

Nu propun o mașină de stări complexă.

---

# 9. Întreruperea generării — 10.2/9

Această funcție este necesară pentru NIMC.

Human trebuie să poată opri o generare fără să oprească întregul actor.

Exemplu:

```text
Human:
  Stop

NIMC:
  trimite cererea de întrerupere

Actor Runtime:
  oprește interacțiunea curentă

MCAD:
  solicită anularea apelului către provider,
  dacă protocolul permite
```

Dar există o limită importantă.

**Anularea unei solicitări nu garantează că providerul nu a consumat deja resurse sau că un instrument nu a produs efecte.**

De aceea, MCAD trebuie să păstreze contabilizarea disponibilă, chiar și pentru cereri întrerupte.

Runtime-ul trebuie să păstreze rezultatul parțial dacă acesta este util.

Nu trebuie să interpreteze automat anularea drept eșec al tuturor operațiilor deja executate.

Această distincție este susținută și de cercetarea LiteLLM din sertare, unde anularea, retry-ul și contabilizarea sunt tratate ca probleme distincte.

---

# 10. Erori și recuperare — 10.2/10

Din proiectele studiate rezultă câteva situații importante.

| Situație | Comportament recomandat |
|---|---|
| Model indisponibil | MCAD raportează indisponibilitatea |
| Model neautorizat | MCAD refuză solicitarea |
| Provider timeout | Runtime-ul primește eroarea și poate continua ulterior |
| Streaming întrerupt | Se păstrează textul primit și starea incompletă |
| Comandă shell eșuată | Rezultatul este transmis modelului |
| Instrument inexistent | Apelul este refuzat fără executare |
| Context prea mare | Se reduce/selectează contextul disponibil |
| Limită de generare atinsă | Se păstrează progresul și se decide continuarea |
| Human întrerupe | Se oprește interacțiunea curentă |

### Retry-ul necesită atenție

Un retry poate fi simplu dacă solicitarea nu a ajuns la provider.

Dar dacă providerul a început procesarea, retrimiterea poate genera consum suplimentar.

La fel, repetarea unei comenzi shell poate modifica din nou fișiere.

Prin urmare:

**Retry-ul inferenței și reluarea instrumentelor sunt operații diferite.**

Nu trebuie să reluăm automat comenzi Linux numai pentru că s-a întrerupt streaming-ul către model.

OpenCode documentează explicit această limită a recuperării. [GitHub](https://github.com/anomalyco/opencode/blob/dev/specs/v2/session.md?utm_source=chatgpt.com)

---

# 11. Ce adaugă proiectele cu modele locale?

Merită clarificată și diferența dintre actorul AI și modelul AI local.

Un model local, de exemplu unul deservit prin Ollama, poate expune un API compatibil cu interfețele obișnuite pentru conversații.

Ollama documentează suport pentru streaming și apeluri către instrumente, inclusiv transmiterea rezultatelor instrumentelor înapoi către model. [GitHub](https://github.com/ollama/ollama/blob/main/docs/api/openai-compatibility.mdx?utm_source=chatgpt.com)

Aceasta înseamnă că putem avea:

```text
Actor Runtime
      |
      | SSH
      v
MCAD
      |
      +---- Provider remote
      |
      +---- Model local pe hostul MCAD
      |
      +---- Model local pe alt host
```

Din perspectiva Actor Runtime, diferența poate rămâne transparentă.

Actorul solicită modelul prin MCAD.

MCAD decide unde este disponibil modelul autorizat și cum se realizează apelul.

**Nu este necesar un Actor Runtime distinct pentru modelele locale.**

Trebuie însă păstrată informația despre capabilitățile modelului. Nu toate modelele sau endpointurile oferă aceleași funcții de streaming, apeluri de instrumente sau procesare multimodală.

---

# 12. Ce putem considera deja rezolvat conceptual?

Revenim la întrebările inițiale din 10.2.

| Întrebarea inițială | Rezultat al cercetării |
|---|---|
| 1. Cum primește runtime-ul o solicitare? | Sursele sunt definite: NIMC și comunicarea echipei; contractul concret rămâne deschis |
| 2. Cum construiește cererea către model? | **Principiul clarificat** prin Qwen Code, Pi și Agents SDK |
| 3. Cum selectează modelul prin MCAD? | **Principiul clarificat** prin LiteLLM și CLIProxyAPI; politica MCA rămâne de definit |
| 4. Cum procesează răspunsurile? | **Clarificat conceptual**: text, evenimente, tool calls, erori |
| 5. Cum transmite streaming? | **Clarificat conceptual**: evenimente incrementale |
| 6. Cum recunoaște tool calls? | **Clarificat conceptual**: apeluri structurate, interpretate de runtime |
| 7. Cum execută instrumentele? | **Mecanism deja disponibil** prin R2/Linux; integrarea cu modelul lipsește |
| 8. Când este complet răspunsul? | **Clarificat conceptual** prin semnalele de finalizare |
| 9. Cum întrerupem generarea? | **Clarificat conceptual** prin anularea interacțiunii, nu a actorului |
| 10. Cum tratăm erorile? | **Principiile clarificate**; politica de recuperare trebuie stabilită |

Prin urmare, nu mai trebuie să dezbatem cele zece întrebări în forma lor inițială.

Cercetarea a redus considerabil zona de incertitudine.

---

# 13. Întrebările rămase — 10.2 reformulat

Aș restrânge dezbaterea la **cinci decizii de arhitectură**.

## 10.2/A — Formatul comun Runtime–MCAD

Ce contract minimal trebuie să ofere MCAD?

Propun să existe o interfață stabilă pentru:

- solicitări către modele;
- streaming;
- răspunsuri finale;
- apeluri de instrumente;
- erori și anulare;
- informații despre consum.

Nu trebuie să inventăm un format complet nou.

**Întrebarea rămasă:** adoptăm ca bază un format API existent, adaptat la transportul SSH, sau definim un subset intern minimal?

Aici LiteLLM, CLIProxyAPI și Pi sunt principalele referințe.

## 10.2/B — Alegerea modelului

Cine selectează modelul concret?

Există mai multe posibilități:

- Human selectează explicit un model aprobat.
- Actorul selectează un model dintre cele aprobate.
- MCAD selectează automat un provider sau un model echivalent, conform configurației.

Aceste posibilități pot coexista.

**Întrebarea rămasă:** câtă libertate acordăm actorului în alegerea modelului și câtă decizie revine MCAD?

Distincția dintre modelul solicitat și modelul utilizat efectiv trebuie păstrată.

## 10.2/C — Motorul AI minimal

Putem implementa în Nim un motor mic, inspirat din Pi, Qwen Code și Runx.

Întrebarea nu mai este cum funcționează un agent AI; mecanismul de bază este cunoscut.

**Întrebarea rămasă:** ce funcționalități includem inițial și ce lăsăm pentru extindere?

Recomand să începem cu conversație text, streaming, un instrument shell și persistență Markdown.

Accesul la CMS, instrumentele suplimentare și capacitățile multimodale pot utiliza ulterior aceeași fundație.

## 10.2/D — Interacțiunea cu Human

Trebuie să stabilim comportamentul motorului când:

- Human introduce un mesaj;
- actorul generează;
- actorul execută un instrument;
- Human întrerupe;
- Human trimite un mesaj nou înainte de finalizarea celui precedent.

Această întrebare se leagă direct de inelul conversațiilor, dar nu trebuie să implementăm deocamdată deservirea multiuser.

**Întrebarea rămasă:** ce comportament dorim pentru o singură conversație activă?

## 10.2/E — Limite și recuperare

Ce limite minime trebuie configurate?

De exemplu:

- durata unui apel către model;
- numărul maxim de continuări automate;
- dimensiunea rezultatelor instrumentelor;
- comportamentul la întreruperea comunicației;
- păstrarea rezultatelor parțiale.

Aceste limite sunt necesare pentru funcționarea previzibilă, dar nu justifică un subsistem separat.

**Întrebarea rămasă:** care dintre limite trebuie stabilite de MCA și care pot fi administrate local de runtime?

---

# 14. Recomandarea arhitecturală rezultată

În urma cercetării, aș simplifica motorul conversațional la următoarea structură:

```text
                  NIMC
                    |
                    v
             ACTOR RUNTIME
                    |
             Conversation Core
                    |
              Agent Loop
                    |
          +---------+---------+
          |                   |
      Model Client         Tool Executor
          |                   |
          v                   v
         MCAD               Linux
          |                   |
      Model Router        Shell / Git / VFS
          |
      AI Provider
          |
      Model Response
          |
          v
      Agent Loop
          |
          v
      Markdown / Git
          |
          v
         NIMC
```

Observăm că nu sunt necesare multe componente.

**Actor Runtime** păstrează conversația, execută bucla AI și folosește instrumentele Linux.

**MCAD** verifică autoritatea, selectează providerul, adaptează API-ul și contabilizează consumul.

**NIMC** afișează dialogul și permite interacțiunea Human.

**Git** păstrează continuitatea.

Această arhitectură poate deservi modele locale și remote fără schimbarea motorului conversațional.

---

## 15. Stadiul cercetării și materialele disponibile

Am folosit două categorii de surse.

**Materiale din sertare:** documentul Technology Watch din 25 octombrie 2026, nota „Scanare proiecte urmărite”, cercetările anterioare recuperate despre cecli, Shuvarie, LiteLLM și alte proiecte, precum și arhiva OpenShell furnizată.

**Surse upstream:** documentația și implementările publice pentru Qwen Code, Pi, OpenCode, Continue, OpenAI Agents SDK, LiteLLM, CLIProxyAPI și Ollama.

Există o limită importantă: documentul Technology Watch consultat este un **supliment la lista de proiecte**, nu inventarul integral al tuturor sertarelor. Prin urmare, nu consider cercetarea exhaustivă asupra întregului catalog urmărit de Sam.

Pentru proiectele `chatgpt.sh`, `bash-agent`, `cecli`, `clai`, `gproxy` și `9router`, avem referințe istorice sau puncte de plecare, dar nu am verificat în această etapă sursele exacte la același nivel ca Qwen Code, Pi, OpenCode sau LiteLLM. Nu le voi atribui funcționalități nedemonstrate.

**Solicitarea unui inventar consolidat de la Sam ar fi utilă**, în special pentru identificarea proiectelor mici, care ar putea oferi implementări mult mai simple decât frameworkurile mari.

---

## 16. Dispoziție Nim

```text
PROJECT=MCA_ACTOR_RUNTIME
TOPIC=10.2_AI_ENGINE

RESEARCH:
  AGENT_RUNTIME=REVIEWED
  MULTI_MODEL_GATEWAYS=REVIEWED
  STREAMING=REVIEWED
  TOOL_CALLING=REVIEWED
  ERROR_HANDLING=REVIEWED
  LOCAL_MODELS=REVIEWED

PRIMARY_REFERENCES:
  ACTOR_CORE=PI_QWEN_CODE_OPENCODE
  MODEL_TOOL_BOUNDARY=RUNX
  MODEL_GATEWAY=LITELLM_CLIPROXYAPI
  CONTEXT=LEANCTX_QWEN_MEMORY
  ISOLATION=OPENSHELL_NACM

REMAINING_DECISIONS:
  A=RUNTIME_MCAD_PROTOCOL
  B=MODEL_SELECTION
  C=MINIMAL_AGENT_LOOP
  D=HUMAN_INTERACTION
  E=LIMITS_AND_RECOVERY

SOURCE_REUSE=NOT_DECIDED
IMPLEMENTATION=NOT_STARTED
OFFICIAL_MUTATION=NONE
```

### Concluzie

**Avem deja suficiente dovezi tehnice pentru a defini principiul de funcționare al motorului conversațional.** Nu trebuie să reconstruim un framework AI complex.

Dar înainte să alegem implementarea în Nim, merită să completăm inventarul Sam și să examinăm mai atent cele mai mici motoare de agent existente.

Aș păstra cele cinci întrebări reformulate, începând cu **10.2/A — contractul dintre Actor Runtime și MCAD**. Acesta va influența puternic cât cod trebuie implementat în runtime și cât poate fi reutilizat din mecanismele gateway-urilor existente.


