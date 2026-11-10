# Bayan Life

A grindy, all-ages Roblox job game. You work jobs in a small Filipino town, rank up, and go from worker to owner.

Notes and design: `Fritz Knowledge/01-projects/bayan-life/bayan-life.md`

## The city (`CityMap.luau`)
```
              Bayan Mall (north, +Z)
                     |
 Town Hall ---- Plaza (spawn) ---- Bakery & Palengke (east, +X)
 (west)  Park (NW)   |   Covered court (SE)
             Houses & sari-sari store (south)
```
- Each workplace is about 140 studs from the plaza (a 10-second walk), connected by roads with lane lines,
  sidewalks, street lamps and trees.
- **Town center (spawn):** a 76×76 walking plaza inside a **ring road** where the 4 main roads meet, with an outer
  sidewalk, curbs and 8 zebra crossings. Inside: a spawn medallion (kept clear), a two-bowl fountain with benches and
  flower beds, a big gazebo, a **clock tower** whose 4 faces show the game time, **food carts** (taho, sorbetes,
  fishball), a jeepney terminal with a marked stop on the ring road (for the future Jeepney Driver job), trees in
  planters, low hedges, lamps, and a **signpost** whose blades point to every place in its real direction.
  The "Welcome to Bayan" arch stands over the south road. The park and the court moved a little to make room.
- **Bayan Park:** walking paths, pond, playground (slide, swings you can sit on, see-saw, sandbox), bahay kubo,
  flower beds, picnic tables.
- **Barangay covered court** with hoops and bleachers.
- **Bakery and Bayan Public Market** side by side on the north side of the east road, on one front line and both
  facing the road, joined by a paved front walk with planters.
- **Bayan Rotonda:** the east road ends in a loop past the bakery (a ring road around an island with flowers and the
  Bayan Monument), so the road turns back instead of dead-ending.
  The market's entrance arch faces the main road; inside, **6 business stalls** line one straight aisle
  (FOR SALE, or the owner's business name).
- **Bayan Heights subdivision:** a big walled, gated subdivision (arch, guard house, boom barrier) with
  **80 premium 2-storey houses**: 5 streets (Sampaguita, Narra, Mabini, Ilang-Ilang, Acacia) crossing **Rizal Avenue**,
  houses on both sides of each street (10 rows of 8, back to back). Each house has a stone accent wall, framed windows,
  a garage with a balcony and glass railing, a flat roof, a stone front wall with railings, a sliding gate, a driveway
  and shrubs, in 5 color styles. Door lamps and upstairs windows light up at night. Green **street signs** at every
  corner, a subdivision map at the gate, and an address plate on every house ("Blk 2 Lot 5").
- **Bayan Mall parking:** a big fenced lot in front of the mall (about 90 spaces, parked cars, lamps), with a
  "BAYAN MALL PARKING" arch, guard booth and boom barrier.
- **Town Hall compound:** an iron fence with a main gate arch, a side gate to its own fenced parking lot (guard booth,
  barrier), and a long **time clock shed** outside the building with all Town Hall time clocks in a row and a line-up rail.
- Cleanup litter appears along the streets, plaza and park.

## What works now (slice 4: real customers, energy)
**Made to order, players only.** Orders come only from real players. No orders = no baking.

Getting hired (one time per job, saved):
- **BAYAN MALL** (behind the spawn point) is a 2-floor mall with a glass front, sliding doors, an atrium with a skylight,
  a grand staircase, a directory, a food court (coming soon) and benches you can sit on. Open 6 AM to 10 PM.
- **2nd floor:** one uniform stall per job. Baker is open: hold E to buy the Baker Uniform (500 coins).
  The other stalls have their shutters down (coming soon).
- **Job Center (1st floor):** "Apply for a Job" opens the application:
  1. choose a job (Baker is open; Jeepney Driver, Sari-sari Clerk, Fisher and Cleanup Crew are coming soon)
  2. requirements check (you need the uniform first)
  3. application form (preferred shift, agree to the rules)
  4. assessment quiz (5 random questions, pass with 4/5, retry after 30 seconds; graded only on the server)
  5. hired!
- **Queue:** the Job Center has 2 service windows (`Config.JobCenter.windows`). Pressing "Apply for a Job" gives you a
  queue number. If a window is free you are served right away; if not, wait on the benches until you are called.
  A NOW SERVING board shows each window. A turn lasts up to 150 seconds; walking away ends it.
- Waiting area with benches and a "Now hiring" job board.
- **🪪 Employee ID:** photo, name, employee number, rank, jobs (hired day, preferred shift) and **work history**:
  lifetime shifts, orders and coins per job, plus your latest shifts.
- You wear the uniform (chef hat and apron) while on shift.

**BAYAN TOWN HALL** (to the side of the spawn, office hours 6 AM to 5 PM):
- Columns, steps, a plaza with a flagpole, trees, benches and lamp posts, and the Cleanup dumpster.
- **Town Hall Job Center** (2 windows, queue, benches) for government jobs (`applyAt = "townhall"`):
  - **🗂️ Application Staff:** clock in at "Time Clock: Staff", press **Take Window** behind any Job Center desk
    (Town Hall or Mall). When an applicant at your window submits the form, a review screen opens: press **Approve**
    to start their quiz (+20 coins, +10 XP). No answer in 30 seconds = approved automatically, no pay.
    Windows without staff run automatically.
  - **🧹 Cleanup Crew:** clock in at "Time Clock: Cleanup", pick up litter around the plaza and paths (bag holds 10,
    shown on your back), empty it at the dumpster: +3 coins and +2 XP per piece from the barangay. Works on an empty server.
    Litter piles up overnight: about 30 pieces appear at 6 AM, a few more until 9 AM, then none until the next morning.
- Each Job Center lists only its own jobs. To move or add a job, set `applyAt` in `Config.Jobs`.

**Owning a business (stage 1, `Business.luau`):**
1. **Barangay Clearance:** kiosk just inside the Town Hall door (100 coins, saved).
2. **Business Permit:** the **BPLO** window at the Town Hall (1 window, queue, benches). The form shows the
   requirements (rank Worker+, clearance, 1,000-coin fee paid on approval), business type (Sari-sari Store) and a
   business name from presets based on your display name. Application Staff at the BPLO window review and approve it
   (+30 coins); with no staff it is approved after a 60-second processing wait.
3. **Market stall:** with a permit, buy the right to a stall (2,000 coins, saved) at a FOR SALE stall in the Bayan
   Public Market. There are 6 stalls. Like tycoon plots, your stall takes a free spot each time you join and shows your business name.
4. The permit and store show on your Employee ID. Running the store (stock, prices, selling) is stage 2.

**Real work life: schedules and payroll ("sahod")**
- Your preferred shift from the application is your **schedule**: Morning 6–11 AM, Afternoon 11 AM–5 PM, Whole day 6 AM–5 PM.
- Clock in more than 10 game minutes after your start = **Late**. Clock out before your end = **Undertime**.
  Working outside your schedule still pays per task, but not by the hour.
- Hours inside your schedule earn an **hourly wage** (Baker 6, Staff 8, Cleanup 5 coins per game hour, times your rank bonus).
  It adds up and is paid on **payday**, every 3 game days (`Config.Payroll`).
- Payday gives a **payslip**: gross pay − **SSS 4.5%**, **PhilHealth 2.5%**, **Pag-IBIG 2%** (withholding tax: exempt) = net pay.
  Missed a payday while offline? You are paid when you join.
- The **💰 Pay** window shows this period, the latest payslip, older payslips and your total contributions.
  The **DTR** now shows paid hours, Late/Undertime, wage and task pay for every shift.

**Renting a house (`Housing.luau`, `HouseInterior.luau`)**
- **Leasing Office** just inside the Bayan Heights gate: "Rent a House" (you must be hired for a job; the first
  150-coin rent is paid upfront) or "End Rent".
- **Rent** (150 per pay period) shows as a "Rent" line on your payslip and comes out of your pay on payday. If your pay
  is not enough, the rest comes from your coins. After 2 missed rents in a row you are moved out.
- Your house takes a **free house** each time you join (tycoon-style), and its sign shows "🏠 Juan's House".
  Empty houses show "FOR RENT".
- **Front door → Enter House:** a private interior with a living room (sofa, TV, rug), a kitchen (counter, dining
  table and chairs, fridge) and a bedroom (bed, wardrobe).
  - **🛏️ Sleep:** full energy, once per game day (screen fades to black).
  - **🧊 Fridge:** store up to 20 bread from your bag (saved).
  - **Open House switch:** lets anyone come in. Locked by default; visitors can knock.
- Your home address shows on your Employee ID.
- **Spawn at home:** if you rent a house, you spawn at its front door (when you join, reset or fall). The admin
  spawns at the mansion. No house = you start at the plaza.

**Bayan Heights II (starter homes, `CityMap.luau`)**
- A **separate subdivision** right next to Bayan Heights (east), with its own walls (a grass strip between the two)
  and its **own main gate** on the north side (arch "BAYAN HEIGHTS II", guard house, barrier, planters).
- **Getting there:** from the plaza, take the east road. Across from the market a sign
  "🏘️ To BAYAN HEIGHTS II" marks the road south; it turns east and reaches the gate.
- Inside: Bonifacio Ave., 4 streets (Blk 6 Gumamela, Blk 7 Molave, Blk 8 Rosal, Blk 9 Kamagong) with **40 pastel row
  houses** (5 on each side of each street), street signs, address plates and a map by the gate.
- A small green with benches by the gate, and a **covered court** and **playground** at the south end.
- **Leasing Office II** on Bonifacio Ave., just inside the gate, rents only Heights II houses, at a cheaper **80 coins per
  pay period** (Bayan Heights stays 150). You rent one house at a time: to move up, End Rent, then rent at the
  other Leasing Office. Rents are in `Config.Housing.areas`.
- Inside, a row house uses the same interior as a Bayan Heights house (for now).

**Veterans Parc and the Admin Mansion (`CityMap.luau`, `Housing.luau`, `Admin.luau`)**
- **Veterans Parc** is a second, smaller subdivision north-east of the plaza, with its own road from the mall avenue.
  The gate has a "VETERANS PARC" arch, pillars, a guard house and a barrier. Anyone can walk in.
- Inside: a tree-lined drive, **6 large villas** ("FOR SALE (coming soon)"), and a **clubhouse** with a pool,
  loungers, umbrellas and a small park.
- **The Admin Mansion** sits at the end of the drive: 3 floors, columns, balconies, a 2-car garage, a pool, a garden,
  a fountain and a name gate ("🏰 The Admin's Residence", which becomes "🏰 Fritz's Residence" when an admin is in town).
- **Free and permanent** for the admin: no rent, never moved out. Only an admin can go in, unless the admin turns on
  **Open House**. Others can knock.
- **Bigger interior:** grand living room with a second sofa and a chandelier, a kitchen island, the master bed and a
  **home office desk**. Sleep, fridge (the same fridge as your rented house) and Open House work like a normal house.
- **Admin parking:** a car gate in the mansion's front wall (with a short drive from the main drive) opens onto a
  motor court with 3 reserved bays ("🅿️ ADMIN PARKING"), a parked white car, and the garage.
- **The admin car (`AdminCar.luau`, `AdminCar.client.luau`):** a black convertible with a gold stripe and an
  "ADMIN" plate, in bay 1. Jump into the driver seat and drive with W/S (gas/reverse) and A/D (steer); top speed 60.
  Only admins can drive it; anyone can ride in the passenger seat. Left alone for a minute away from its bay (or
  fallen off the map), it goes back to its bay by itself.
- **Admin announcements (`Announcements.luau`, `Announcements.client.luau`):** type `/announce your message` (or
  `/ann ...`) in chat, or press **📢 Announce** under the coins card (admins only). Every player sees a banner at the top
  of the screen for 8 seconds: "📢 Admin Fritz" and the message. Up to 150 characters, one every 5 seconds, and the
  text goes through Roblox's text filter. Sound slot: `Config.Sounds.announce`.
- **Who is an admin:** the game owner (once the place is published under your account), plus the user IDs in
  `Config.Admins`, for example `Config.Admins = { [12345678] = true }`. In Studio Play you are always the admin
  (`Config.StudioOwnerIsAdmin`; set it to false to test as a normal player).

**Polish (look, sound, feel)**
- **Lighting:** soft haze, gentle glow, warm colors, softer nights (`Atmosphere.luau`).
- **Street lamps** turn on at 5:30 PM and off at dawn (`CityLights.client.luau`).
- **Effects:** flames in the oven, chimney smoke drifting in the wind, fountain spray.
- **Holding pose:** a baker's arms reach forward while carrying the bread tray (`Poses.luau`).
- **Coins pop:** "+12 🪙" floats up when you earn, red when you spend.
- **Buttons and windows:** grow on hover, bounce on click, windows pop open and shrink closed.
- **Welcome tutorial:** 6 short pages for new players (once), reopen with the ❓ Help button under the coins card.
- **Sounds:** clicks and messages use a built-in sound. Other sounds (payday, coins, doors, fountain, oven, good/bad/fanfare)
  are empty slots in `Config.Sounds`: in Studio, open Toolbox → Audio, pick a sound by Roblox, right-click → Copy Asset ID,
  and paste it as `"rbxassetid://123456"`.

All jobs share one shift system (`Shifts.luau`): requirements, work hours, energy, closing time, uniforms
(`Uniforms.luau`) and the DTR. A player works one job at a time.

Open and closed:
- The bakery (6 AM to 5 PM) and the mall (6 AM to 10 PM) have sliding doors and an OPEN / CLOSED sign.
  At closing time, anyone inside is walked out front and the doors shut (`Establishments.luau`).

Baker (on shift):
- Clock in at the **Time Clock** (6:00 AM to 5:00 PM game time; needs 10+ energy).
- When a customer orders, the order shows in your job panel. **Oven:** pick the breads your orders need (green cards, or keys 1-4).
- Bread bakes onto the **Bread Racks**. Pick it up (you carry a tray), then press **Serve Orders** behind the counter.
  This stocks the **glass case** and serves every order it can fill.
- You get the customer's coins (plus a rank bonus) and XP. Serve within 90 seconds for bonus XP.
- Working uses energy (about 8 per real minute). At 0 you are sent home.

Customer (off shift):
- Press **Order Bread** at "Order Here" in front of the counter. Pick breads with + and -, then **Place Order**.
- You pay when you order. The order goes to the working baker with the fewest orders.
- Served bread goes to your **🎒 Bag**. Eat it to refill energy. Not served in 3 minutes = full refund.

Everyone:
- **Energy** bar (0-100). Each new day at 6:00 AM, energy refills to at least 40.
- **Work hours:** a game clock (top left, above the coins card; ❓ Help and 📢 Announce sit under the card) and a sun that follows it. 5:00 PM = everyone clocked out, open orders refunded.
- **DTR:** every shift logs day, job, time in, time out, orders and coins earned (📋 DTR button).
- Ranks: Helper → Worker → Boss. Higher rank = bigger pay bonus and new breads to bake.
- Prompts only show for your role (bakers see work prompts, customers see Order Bread).
- Brand-new players get **5,000 starter coins** once (`Config.Economy.starterCoins`).
- Coins, XP, energy, bag and DTR save (DataStore).

| Bread | Energy | Price | Bake unlock |
|---|---|---|---|
| Pandesal | +10 | 3 | Helper |
| Spanish Bread | +15 | 5 | Helper |
| Pan de Coco | +20 | 7 | Worker |
| Ensaymada | +30 | 10 | Boss |

## Run it
1. Install Rojo 7.7.1 and its Studio plugin (`rojo plugin install`).
2. In VS Code, open this folder and run `rojo serve`.
3. In Roblox Studio, open a new **Baseplate** place. Open the Rojo plugin and click **Connect**.
4. Press **Play**. You start at the plaza (or at your house, if you rent one).

To test orders you need 2 players: **Test → Clients and Servers**, pick 2 players, then **Start**.
One player clocks in (baker), the other orders (customer).

Saving only works in Studio after you publish the place and turn on
**Game Settings → Security → Enable Studio Access to API Services**.
Until then, the HUD says "Progress is not saving".

## Working together (2 coders)
The files in this repo are the real game: the map and every script are built by code. Roblox Team Create
does not share these files, so we share them on GitHub and Rojo puts them into Studio.

**First time (collaborator)**
1. Accept the GitHub invite, then download the code: `git clone <repo link>` (or GitHub Desktop).
2. Install Rojo **7.7.1** (same version) and the Studio plugin: `rojo plugin install`.
3. Open the folder in VS Code and run `rojo serve`. In Studio, open a Baseplate and click **Connect**.

**Every time you work**
1. Get the latest code first: `git pull`.
2. Make a branch for your task: `git checkout -b your-task-name`.
3. Edit scripts **only in the files** (VS Code), never in Studio. Rojo overwrites Studio script edits.
4. Test in **your own** Studio place (a Baseplate, or a copy of the game), not the shared one.
5. Save your work: `git add .`, `git commit -m "what you changed"`, `git push`.
6. Open a Pull Request on GitHub. The other person checks it, then merges it into `main`.

**Rules that prevent lost work**
- Only **one** person connects Rojo to the shared (published) place at a time. The owner syncs `main` into it.
- Split the work by files (for example: one person on the map, one on jobs). Avoid editing the same file at once.
- Do not edit `Config.luau` numbers for balance without telling the other person.

## Files
| File | What it does |
|---|---|
| `src/shared/Config.luau` | All numbers: ranks, breads, prices, energy, clock. Balance the game here. |
| `src/shared/Progression.luau` | Rank math, shared by server and client |
| `src/shared/GameClock.luau` | Game time of day from server time |
| `src/shared/Admin.luau` | Who is an admin (game owner, `Config.Admins`, you in Studio) |
| `src/server/Housing.luau` | Leasing Office, rent, house lots, doors, the Admin Mansion |
| `src/server/HouseInterior.luau` | House interiors (normal and the grand mansion) |
| `src/server/AdminCar.luau` | The admin's drivable car: build, admin-only driver seat, return to its bay |
| `src/client/AdminCar.client.luau` | Driving the admin car (speed and steering) |
| `src/server/Announcements.luau` | Admin announcements: admin check, text filter, send to everyone |
| `src/client/Announcements.client.luau` | /announce command, 📢 button and window, the banner |
| `src/server/Main.server.luau` | Starts everything |
| `src/server/PlayerData.luau` | Load, save and change coins, XP, energy, bag, DTR |
| `src/server/Energy.luau` | Eating bread, night rest |
| `src/server/BakeryOrders.luau` | The order board: place, assign, refund, complete |
| `src/server/BakeryJob.luau` | Shifts, oven, racks, serving, pay, work hours, energy use |
| `src/server/BakeryMap.luau` | Builds the bakery, or uses your own `Bakery` model |
| `src/server/MallMap.luau` | Builds the 2-floor BAYAN MALL, or uses your own `Mall` model |
| `src/server/JobCenter.luau` | Uniform stalls, both Job Centers, queue, staff windows and reviews, quiz, hiring |
| `src/server/Establishments.luau` | Opening hours: doors, OPEN/CLOSED signs, walking people out at closing |
| `src/server/Shifts.luau` | Shifts for every job: clock in/out, requirements, hours, energy, closing, DTR |
| `src/server/Uniforms.luau` | Uniforms worn on shift (baker, staff, cleanup) |
| `src/server/MapKit.luau` | Building helpers (used by the Town Hall and the city) |
| `src/server/CityMap.luau` | The city: roads, plaza, park, court, palengke, houses, sari-sari store |
| `src/server/TownHallMap.luau` | Builds the Town Hall and plaza, or uses your own `TownHall` model |
| `src/server/CleanupJob.luau` | Cleanup Crew: litter, bag, dumpster, pay |
| `src/client/StaffReview.client.luau` | Review screen for Application Staff (job applications and permits) |
| `src/server/Business.luau` | Barangay Clearance, permit checks and issuing, market stalls |
| `src/server/Payroll.luau` | Payday every few game days (payslips are made in PlayerData) |
| `src/client/PayslipPanel.client.luau` | The 💰 Pay window: pay period, payslips, contributions |
| `src/client/PermitForm.client.luau` | Business Permit application form |
| `src/client/JobApplication.client.luau` | Job application window (steps 1-3) |
| `src/client/QuizWindow.client.luau` | The assessment quiz (step 4) and result (step 5) |
| `src/client/EmployeeCard.client.luau` | Employee ID card with work history |
| `src/client/Ui.luau` | Shared colors, helpers and windows for all screens |
| `src/client/Hud.client.luau` | Stats, energy, clock, job panel / your order, pop-ups, prompt roles |
| `src/client/OvenMenu.client.luau` | Oven bread cards |
| `src/client/OrderMenu.client.luau` | Customer order menu |
| `src/client/BagPanel.client.luau` | Bag: eat bread |
| `src/client/DtrPanel.client.luau` | Daily Time Record table |
| `src/client/BakeryShelves.client.luau` | Bread on the racks and in the glass case |

To use your own bakery art: make a Model named `Bakery` in Workspace with parts named
`TimeClock`, `ServeSpot`, `OrderSpot`, `Oven`, `TrashBin` and `BreadRack`
(see the top of `BakeryMap.luau`).
