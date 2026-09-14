# Food delivery — test cases

1000 cases across a self-written mini-eats service (a real SQLite store behind the customer, merchant, driver and admin apps) and the live TheMealDB API. Generated from `../features/*.feature` by `build.js`; do not edit by hand.

## minieats-db (33)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 1 | BE/DB | High | The store has the documented tables |
| 2 | BE/DB | High | A menu item name is unique within its restaurant |
| 3 | BE/DB | High | Order lines reference a real order and a real menu item |
| 4 | BE/DB | High | Amounts and quantities are bounded by CHECK |
| 5 | BE/DB | High | An order status is one of the lifecycle states |
| 6 | BE/DB | High | An order event names a known actor |
| 7 | BE/DB | Medium | A ledger entry is a real, non-zero amount with a known reason and party |
| 8 | BE/DB | Medium | A driver status is one of the known states |
| 9 | BE/DB | Medium | The commission rate is a fraction between nothing and everything |
| 10 | BE/DB | Medium | Seeding twice leaves the same rows |
| 11 | BE/DB | High | A checkout creates an order whose total is its subtotal plus the delivery fee |
| 12 | BE/DB | High | Order lines capture the price at order time |
| 13 | BE/DB | High | Checkout decrements stock by the ordered quantity |
| 14 | BE/DB | High | An oversell is refused and leaves the store untouched |
| 15 | BE/DB | Medium | An empty cart cannot be checked out |
| 16 | BE/DB | Medium | A checked-out cart is marked ordered |
| 17 | BE/DB | Medium | The order belongs to the customer who placed it |
| 18 | BE/DB | Medium | One order line per distinct cart line |
| 19 | BE/DB | High | Placing an order writes the opening event |
| 20 | BE/DB | High | Accepting an order records the transition and moves the status |
| 21 | BE/DB | High | Rejecting a placed order restocks it and records the transition |
| 22 | BE/DB | High | Cancelling a placed order restocks it and records the transition |
| 23 | BE/DB | High | A full lifecycle writes an event for every transition |
| 24 | BE/DB | High | On delivery the restaurant is paid its subtotal less commission |
| 25 | BE/DB | High | On delivery the driver is paid the delivery fee and the platform takes the commission |
| 26 | BE/DB | High | The delivery ledger sums to the order total |
| 27 | BE/DB | Medium | An undelivered order has posted nothing to the ledger |
| 28 | BE/DB | High | A repeated checkout with the same idempotency key makes one order |
| 29 | BE/DB | Medium | No order line references a missing menu item |
| 30 | BE/DB | Medium | No order references a missing customer or restaurant |
| 31 | BE/DB | Medium | Checkout of <label> decrements its stock and captures its price |
| 32 | BE/DB | Medium | Checkout of <label> decrements its stock and captures its price |
| 33 | BE/DB | Medium | Checkout of <label> decrements its stock and captures its price |

## minieats-api (902)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 34 | BE/API | High | /restaurants lists the active restaurants only |
| 35 | BE/API | High | /restaurants/:id/menu matches the rows, priced from them |
| 36 | BE/API | Medium | The menu marks an out-of-stock item and an unavailable item as unavailable |
| 37 | BE/API | Medium | /restaurants/:id hides an inactive restaurant and 404s the unknown |
| 38 | BE/API | High | Opening a cart requires a customer token |
| 39 | BE/API | High | A cart cannot be opened at a closed restaurant |
| 40 | BE/API | High | Adding an item reflects the row and the line total |
| 41 | BE/API | Medium | Adding the same item twice merges into one line |
| 42 | BE/API | High | A quantity beyond stock is refused |
| 43 | BE/API | Medium | An item from another restaurant cannot be added |
| 44 | BE/API | Medium | An out-of-stock item cannot be added |
| 45 | BE/API | Medium | An unavailable item cannot be added |
| 46 | BE/API | Low | A non-positive quantity is rejected |
| 47 | BE/API | Low | An unknown cart is 404 |
| 48 | BE/API | High | Checkout requires a customer token |
| 49 | BE/API | High | A checkout returns an order equal to the stored order |
| 50 | BE/API | High | The order total in the response is its subtotal plus the delivery fee |
| 51 | BE/API | Medium | An empty cart cannot be checked out |
| 52 | BE/API | High | A tracked order carries its lifecycle events |
| 53 | BE/API | Medium | A retried checkout with the same idempotency key returns the same order |
| 54 | BE/API | Low | An unknown order is 404 |
| 55 | BE/API | High | A merchant advances a placed order through to ready |
| 56 | BE/API | High | A merchant cannot accept an order that is not placed |
| 57 | BE/API | High | A merchant cannot prepare an order that was never accepted |
| 58 | BE/API | High | A merchant rejects a placed order |
| 59 | BE/API | High | A customer can cancel a placed order but not one already accepted |
| 60 | BE/API | High | A customer cannot cancel once the merchant has accepted |
| 61 | BE/API | High | A customer cannot cancel another customer's order |
| 62 | BE/API | High | A ready order is offered to drivers; an unready one is not |
| 63 | BE/API | High | Reading the offers requires a driver token |
| 64 | BE/API | High | A driver assigns, picks up and delivers a ready order |
| 65 | BE/API | High | An order cannot be assigned to a second driver |
| 66 | BE/API | High | Only the assigned driver may pick up the order |
| 67 | BE/API | High | A ready order cannot be delivered before it is picked up |
| 68 | BE/API | Medium | An order cannot be assigned before it is ready |
| 69 | BE/API | Medium | A merchant sees its own restaurant's orders |
| 70 | BE/API | Medium | A merchant can filter its board by status |
| 71 | BE/API | High | The admin overview requires the admin token |
| 72 | BE/API | High | The admin overview counts a delivered order and its revenue |
| 73 | BE/API | High | The admin overview's money balances -- revenue equals payouts plus commission plus fees |
| 74 | BE/API | Medium | The admin can list orders and filter them by status |
| 75 | BE/API | High | The admin deactivates a restaurant and it disappears from the customer list |
| 76 | BE/API | Low | Deactivating an unknown restaurant is 404 |
| 77 | BE/API | Medium | A consistent error shape and a 404 for unknown routes |
| 78 | BE/API | Low | The health endpoint reports the seeded restaurant count |
| 79 | BE/API | Medium | An order at restaurant <rid> can be driven to delivered |
| 80 | BE/API | Medium | An order at restaurant <rid> can be driven to delivered |
| 81 | BE/API | Medium | An order at restaurant <rid> can be driven to delivered |
| 147 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 148 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 149 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 150 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 151 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 152 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 153 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 154 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 155 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 156 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 157 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 158 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 159 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 160 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 161 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 162 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 163 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 164 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 165 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 166 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 167 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 168 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 169 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 170 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 171 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 172 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 173 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 174 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 175 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 176 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 177 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 178 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 179 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 180 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 181 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 182 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 183 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 184 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 185 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 186 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 187 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 188 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 189 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 190 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 191 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 192 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 193 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 194 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 195 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 196 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 197 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 198 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 199 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 200 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 201 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 202 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 203 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 204 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 205 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 206 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 207 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 208 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 209 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 210 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 211 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 212 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 213 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 214 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 215 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 216 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 217 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 218 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 219 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 220 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 221 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 222 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 223 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 224 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 225 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 226 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 227 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 228 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 229 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 230 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 231 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 232 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 233 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 234 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 235 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 236 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 237 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 238 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 239 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 240 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 241 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 242 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 243 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 244 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 245 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 246 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 247 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 248 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 249 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 250 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 251 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 252 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 253 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 254 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 255 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 256 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 257 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 258 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 259 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 260 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 261 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 262 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 263 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 264 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 265 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 266 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 267 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 268 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 269 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 270 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 271 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 272 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 273 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 274 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 275 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 276 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 277 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 278 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 279 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 280 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 281 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 282 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 283 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 284 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 285 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 286 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 287 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 288 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 289 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 290 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 291 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 292 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 293 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 294 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 295 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 296 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 297 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 298 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 299 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 300 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 301 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 302 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 303 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 304 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 305 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 306 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 307 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 308 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 309 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 310 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 311 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 312 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 313 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 314 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 315 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 316 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 317 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 318 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 319 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 320 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 321 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 322 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 323 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 324 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 325 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 326 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 327 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 328 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 329 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 330 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 331 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 332 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 333 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 334 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 335 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 336 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 337 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 338 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 339 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 340 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 341 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 342 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 343 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 344 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 345 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 346 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 347 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 348 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 349 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 350 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 351 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 352 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 353 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 354 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 355 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 356 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 357 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 358 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 359 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 360 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 361 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 362 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 363 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 364 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 365 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 366 | BE/API | Medium | A cart line of <qty> of item <iid> at restaurant <rid> is priced from the row |
| 367 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 368 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 369 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 370 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 371 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 372 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 373 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 374 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 375 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 376 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 377 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 378 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 379 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 380 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 381 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 382 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 383 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 384 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 385 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 386 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 387 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 388 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 389 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 390 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 391 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 392 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 393 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 394 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 395 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 396 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 397 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 398 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 399 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 400 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 401 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 402 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 403 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 404 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 405 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 406 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 407 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 408 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 409 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 410 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 411 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 412 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 413 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 414 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 415 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 416 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 417 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 418 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 419 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 420 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 421 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 422 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 423 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 424 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 425 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 426 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 427 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 428 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 429 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 430 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 431 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 432 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 433 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 434 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 435 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 436 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 437 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 438 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 439 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 440 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 441 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 442 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 443 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 444 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 445 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 446 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 447 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 448 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 449 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 450 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 451 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 452 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 453 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 454 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 455 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 456 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 457 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 458 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 459 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 460 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 461 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 462 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 463 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 464 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 465 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 466 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 467 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 468 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 469 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 470 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 471 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 472 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 473 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 474 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 475 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 476 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 477 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 478 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 479 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 480 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 481 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 482 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 483 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 484 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 485 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 486 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 487 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 488 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 489 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 490 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 491 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 492 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 493 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 494 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 495 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 496 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 497 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 498 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 499 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 500 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 501 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 502 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 503 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 504 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 505 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 506 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 507 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 508 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 509 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 510 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 511 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 512 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 513 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 514 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 515 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 516 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 517 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 518 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 519 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 520 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 521 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 522 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 523 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 524 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 525 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 526 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 527 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 528 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 529 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 530 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 531 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 532 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 533 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 534 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 535 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 536 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 537 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 538 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 539 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 540 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 541 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 542 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 543 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 544 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 545 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 546 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 547 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 548 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 549 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 550 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 551 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 552 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 553 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 554 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 555 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 556 | BE/API | Medium | A cart at restaurant <rid> with <qa> of item <ia> and <qb> of item <ib> subtotals to its lines |
| 557 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 558 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 559 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 560 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 561 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 562 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 563 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 564 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 565 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 566 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 567 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 568 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 569 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 570 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 571 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 572 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 573 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 574 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 575 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 576 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 577 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 578 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 579 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 580 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 581 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 582 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 583 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 584 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 585 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 586 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 587 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 588 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 589 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 590 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 591 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 592 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 593 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 594 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 595 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 596 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 597 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 598 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 599 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 600 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 601 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 602 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 603 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 604 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 605 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 606 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 607 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 608 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 609 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 610 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 611 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 612 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 613 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 614 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 615 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 616 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 617 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 618 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 619 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 620 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 621 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 622 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 623 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 624 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 625 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 626 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 627 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 628 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 629 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 630 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 631 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 632 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 633 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 634 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 635 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 636 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 637 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 638 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 639 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 640 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 641 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 642 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 643 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 644 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 645 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 646 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 647 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 648 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 649 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 650 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 651 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 652 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 653 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 654 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 655 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 656 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 657 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 658 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 659 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 660 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 661 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 662 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 663 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 664 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 665 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 666 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 667 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 668 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 669 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 670 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 671 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 672 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 673 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 674 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 675 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 676 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 677 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 678 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 679 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 680 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 681 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 682 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 683 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 684 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 685 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 686 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 687 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 688 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 689 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 690 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 691 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 692 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 693 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 694 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 695 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 696 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 697 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 698 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 699 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 700 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 701 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 702 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 703 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 704 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 705 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 706 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 707 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 708 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 709 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 710 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 711 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 712 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 713 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 714 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 715 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 716 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 717 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 718 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 719 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 720 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 721 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 722 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 723 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 724 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 725 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 726 | BE/API | Medium | Adding <qty> of item <iid> at restaurant <rid> beyond its stock is refused |
| 727 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 728 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 729 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 730 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 731 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 732 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 733 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 734 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 735 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 736 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 737 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 738 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 739 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 740 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 741 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 742 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 743 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 744 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 745 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 746 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 747 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 748 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 749 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 750 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 751 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 752 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 753 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 754 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 755 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 756 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 757 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 758 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 759 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 760 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 761 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 762 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 763 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 764 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 765 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 766 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 767 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 768 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 769 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 770 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 771 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 772 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 773 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 774 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 775 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 776 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 777 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 778 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 779 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 780 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 781 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 782 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 783 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 784 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 785 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 786 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 787 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 788 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 789 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 790 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 791 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 792 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 793 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 794 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 795 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 796 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 797 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 798 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 799 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 800 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 801 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 802 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 803 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 804 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 805 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 806 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 807 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 808 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 809 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 810 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 811 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 812 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 813 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 814 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 815 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 816 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 817 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 818 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 819 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 820 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 821 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 822 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 823 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 824 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 825 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 826 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 827 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 828 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 829 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 830 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 831 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 832 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 833 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 834 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 835 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 836 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 837 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 838 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 839 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 840 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 841 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 842 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 843 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 844 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 845 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 846 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 847 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 848 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 849 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 850 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 851 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 852 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 853 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 854 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 855 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 856 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 857 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 858 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 859 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 860 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 861 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 862 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 863 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 864 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 865 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 866 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 867 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 868 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 869 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 870 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 871 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 872 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 873 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 874 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 875 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 876 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 877 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 878 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 879 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 880 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 881 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 882 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 883 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 884 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 885 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 886 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 887 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 888 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 889 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 890 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 891 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 892 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 893 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 894 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 895 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 896 | BE/API | Medium | At restaurant <rid>, adding <qty> of the foreign item <iid> is not found |
| 897 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 898 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 899 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 900 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 901 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 902 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 903 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 904 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 905 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 906 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 907 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 908 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 909 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 910 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 911 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 912 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 913 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 914 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 915 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 916 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 917 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 918 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 919 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 920 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 921 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 922 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 923 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 924 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 925 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 926 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 927 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 928 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 929 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 930 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 931 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 932 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 933 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 934 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 935 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 936 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 937 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 938 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 939 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 940 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 941 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 942 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 943 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 944 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 945 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 946 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 947 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 948 | BE/API | Medium | Adding <qty> of the out-of-stock item 3 at restaurant 1 is refused |
| 949 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 950 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 951 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 952 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 953 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 954 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 955 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 956 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 957 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 958 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 959 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 960 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 961 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 962 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 963 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 964 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 965 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 966 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 967 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 968 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 969 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 970 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 971 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 972 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 973 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 974 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 975 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 976 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 977 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 978 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 979 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 980 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 981 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 982 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 983 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 984 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 985 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 986 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 987 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 988 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 989 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 990 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 991 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 992 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 993 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 994 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 995 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 996 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 997 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 998 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 999 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |
| 1000 | BE/API | Medium | Adding <qty> of the unavailable item 4 at restaurant 1 is refused |

## mealdb-api (25)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 82 | BE/API | High | The category list answers and is non-empty |
| 83 | BE/API | High | Every category has an id and a name |
| 84 | BE/API | High | Every category id is unique |
| 85 | BE/API | Medium | Every category name is non-empty when trimmed |
| 86 | BE/API | Medium | Every category thumbnail is an http(s) URL |
| 87 | BE/API | Low | The categories are stable across two reads |
| 88 | BE/API | High | Filtering by a category returns a non-empty list |
| 89 | BE/API | High | Every filtered meal has an id, a name and a thumbnail |
| 90 | BE/API | Medium | No filtered meal id repeats |
| 91 | BE/API | Medium | Every filtered meal id is a positive integer |
| 92 | BE/API | Low | Every filtered meal thumbnail is an http(s) URL |
| 93 | BE/API | Medium | Filtering by "<cat>" returns a non-empty list of real meals |
| 94 | BE/API | Medium | Filtering by "<cat>" returns a non-empty list of real meals |
| 95 | BE/API | Medium | Filtering by "<cat>" returns a non-empty list of real meals |
| 96 | BE/API | High | Looking up a meal by id returns that meal |
| 97 | BE/API | High | A looked-up meal carries instructions, a category and an area |
| 98 | BE/API | Medium | A looked-up meal lists at least one ingredient |
| 99 | BE/API | Medium | An unknown meal id returns no meal |
| 100 | BE/API | High | Searching by name returns the named meal |
| 101 | BE/API | Medium | A search that matches nothing returns no meals |
| 102 | BE/API | Medium | Searching by first letter returns meals that start with it |
| 103 | BE/API | Low | A common ingredient name search returns at least one meal |
| 104 | BE/API | Medium | A filtered meal, looked up, reports the same category |
| 105 | BE/API | Medium | The category-name list agrees with the categories endpoint |
| 106 | BE/API | Low | The area list is non-empty |

## minieats-fe (26)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 107 | FE/UI | High | The home page lists exactly the active restaurants |
| 108 | FE/UI | High | The inactive restaurant does not appear on the home page |
| 109 | FE/UI | Medium | Each home row links to its restaurant page |
| 110 | FE/UI | Low | The home page is not empty |
| 111 | FE/UI | High | A menu shows each item's price from its row |
| 112 | FE/UI | High | The out-of-stock item is shown unavailable |
| 113 | FE/UI | Medium | An in-stock item is shown available |
| 114 | FE/UI | Medium | Every menu price on screen is a dollar amount |
| 115 | FE/UI | Medium | Each menu name matches its item row |
| 116 | FE/UI | Medium | An unknown restaurant page is not found |
| 117 | FE/UI | Medium | The menu for restaurant <rid> is non-empty and priced from the rows |
| 118 | FE/UI | Medium | The menu for restaurant <rid> is non-empty and priced from the rows |
| 119 | FE/UI | Medium | The menu for restaurant <rid> is non-empty and priced from the rows |
| 120 | FE/UI | High | An order page shows the total the order was placed at |
| 121 | FE/UI | Medium | An order page shows the order id and its status |
| 122 | FE/UI | Medium | The order page total is a dollar amount |
| 123 | FE/UI | Low | An unknown order page is not found |
| 124 | FE/UI | High | A delivered order shows a delivered status on its page |
| 125 | FE/UI | High | A placed order appears on its restaurant's merchant board |
| 126 | FE/UI | Medium | Every order on the merchant board shows a dollar total |
| 127 | FE/UI | High | A ready order is offered on the driver board with its fee |
| 128 | FE/UI | Medium | The driver board offer count matches the API |
| 129 | FE/UI | Low | Every offered delivery fee is a dollar amount |
| 130 | FE/UI | High | The admin page shows the revenue as a dollar amount |
| 131 | FE/UI | High | The admin page counts a delivered order |
| 132 | FE/UI | Medium | Every admin status count is a non-negative integer |

## minieats-security (14)

| ID | Layer | Priority | Title |
|---|---|---|---|
| 133 | BE/API | High | Advancing an order requires a merchant token |
| 134 | BE/API | High | A merchant cannot advance an order at a restaurant it does not own |
| 135 | BE/API | High | The owning merchant advances its own order |
| 136 | BE/API | High | A customer token is not accepted as a merchant |
| 137 | BE/API | High | A driver token is not accepted as a merchant |
| 138 | BE/API | High | The order board requires authentication |
| 139 | BE/API | High | A merchant cannot read another restaurant's board |
| 140 | BE/API | Medium | The admin can read any restaurant's board |
| 141 | BE/API | High | The admin overview rejects a non-admin token |
| 142 | BE/API | High | The driver offers reject a non-driver token |
| 143 | BE/API | High | A token that only looks like the admin token is rejected |
| 144 | BE/API | High | A forged bearer token is refused on both a customer and a merchant route |
| 145 | BE/API | Medium | Merchant onboarding is open and issues a token |
| 146 | BE/API | Medium | An order response never carries a bearer token |
