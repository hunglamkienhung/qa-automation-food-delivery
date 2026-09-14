# qa-automation-food-delivery

![Pytest-BDD](https://img.shields.io/badge/Pytest--BDD-tests-0A9EDC?logo=pytest&logoColor=white)
![Cucumber](https://img.shields.io/badge/Cucumber-BDD-23D96C?logo=cucumber&logoColor=white)
![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?logo=playwright&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-store-003B57?logo=sqlite&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Node](https://img.shields.io/badge/Node-24-5FA04E?logo=nodedotjs&logoColor=white)
[![CI](https://github.com/hunglamkienhung/qa-automation-food-delivery/actions/workflows/ci.yml/badge.svg)](https://github.com/hunglamkienhung/qa-automation-food-delivery/actions/workflows/ci.yml)

Bộ QA automation cho một domain **giao đồ ăn**, dựng như một hệ thống chạy được
chứ không phải slide trình chiếu. Một nền tảng giao hàng — **bốn app** (khách,
cửa hàng, tài xế, admin) chung một vòng đời đơn hàng — được kiểm ở **mọi tầng nó
có** (database, API, giao diện) bởi **hai stack độc lập** (Node + Cucumber,
Python + pytest-bdd) cùng đọc **một** bộ Gherkin và phải cho **cùng một kết luận
cho mọi case**.

Không cần tài khoản, không cần key, không cần dịch vụ trả phí. Clone về là chạy.

[English](README.md) · [Chấm điểm](docs/GRADING.md) ·
[Gherkin](docs/GHERKIN.md) · [Định dạng hàng đợi](docs/QUEUE-FORMAT.md)

## Hai hệ thống được kiểm

| Hệ thống | Truy cập | Là gì |
|---|---|---|
| **mini-eats** | đọc + ghi, DB thật | Nền tảng giao hàng nhỏ trong `services/mini-eats`: một file SQLite, chỉ dùng thư viện chuẩn của Node, REST API phục vụ bốn app, và các trang HTML gắn nhãn cho Playwright. |
| **themealdb.com** | chỉ đọc, live | API công thức món ăn live — những món một nhà hàng có thể nấu — không ai chỉnh cho nó "pass" được. |

**146 case**, mỗi case một ID bất biến, chạy trên **cả hai** stack và đối chiếu
từng case. Mọi tầng nền tảng có đều được kiểm ở đúng tầng đó:

| Tầng | Đích | Case | Ở đâu |
|---|---|---|---|
| DB | SQLite mini-eats, đọc trực tiếp | 33 | `be/db` |
| API | REST mini-eats — bốn app + vòng đời | 48 | `be/api` |
| API | ranh giới phân quyền mini-eats (security) | 14 | `be/api` |
| API | API công khai TheMealDB | 25 | `be/api` |
| FE | các màn app mini-eats (Playwright) | 26 | `fe/ui` |
| | **Tổng** | **146** | |

**Tầng security** dò API như kẻ tấn công — request không token, token sai vai,
token giả, hoặc token hợp lệ nhưng cho tài nguyên không phải của mình đều bị từ
chối (401 chưa xác thực vs 403 bị cấm), kèm ca đối chứng dương để chắc đó là cổng
thật chứ không phải endpoint hỏng. Dựng nó **phát hiện và vá 2 lỗ hổng thật**: "app
merchant" trước đây **không hề xác thực** (ai cũng đẩy được đơn của mọi nhà hàng —
leo thang đặc quyền) và bảng đơn lộ đơn của mọi nhà hàng cho bất kỳ ai. Giờ merchant
là actor có xác thực thật, sở hữu nhà hàng của mình.

`mini-eats` là nơi có các đường **ghi**. Một đơn chạy theo máy trạng thái —
`placed → accepted → preparing → ready → picked_up → delivered`, với
`cancelled`/`rejected` là các nhánh thoát khỏi `placed` — và mỗi chuyển trạng
thái bị chặn theo **bạn là ai** (tài xế không được accept, cửa hàng không được
deliver) và theo **đơn đang ở trạng thái nào** (không nhảy cóc bước nào). Checkout
là một giao dịch: đọc lại tồn kho, từ chối bán quá, chốt giá tại thời điểm đặt, và
bất biến theo khóa idempotency; mỗi chuyển trạng thái được ghi vào `order_events`;
và khi giao xong, tiền phải trả được ghi vào `ledger` với ba khoản — cửa hàng
(subtotal trừ hoa hồng), tài xế (phí giao), nền tảng (hoa hồng) — **cộng lại đúng
bằng tổng đơn**. Schema chặn những gì một nền tảng không được phép làm sai: mỗi đơn
một tài xế, tồn kho và tiền không âm, hoa hồng là một phân số thật, trạng thái và
tác nhân nằm trong tập đã biết.

## Hai ý đáng dừng lại một phút

**Một bộ Gherkin, hai stack, một kết luận.** `features/*.feature` dùng chung.
`node/` chạy bằng Cucumber; `python/` chạy chính các file đó bằng pytest-bdd. Một
case lệch nhau giữa hai bên tự nó là một phát hiện — logic chấm điểm đang bị đọc
khác nhau ở hai nơi — và build fail vì điều đó.

**Failed > Blocked > Passed, và sự cố hạ tầng không bao giờ là fail.** Một case
Failed chỉ khi một mệnh đề quan sát được là sai. Khi nguồn live (TheMealDB, một
service đang tắt) không truy cập được, case là **Blocked**, không phải Failed —
nên mạng chập chờn không thể giả dạng một "bếp hỏng". Cổng CI kiểm *hình dạng* của
lượt chạy so với `fixtures/expected-results.json`: fail cả khi Passed thành Failed
(hồi quy) lẫn khi Failed thành Passed (một phép kiểm ngừng kiểm). Xem
[docs/GRADING.md](docs/GRADING.md).

## Chạy trong 30 giây

Thứ nhanh nhất chứng minh bộ máy hoạt động, không cần gì bên ngoài:

```bash
# lõi chấm điểm dùng chung, cả hai stack
cd core/node && node --test "selftest/*.test.js"
cd ../python && pip install -e . && python -m pytest selftest -q
```

## Chạy cả bộ

Mỗi bước dưới đây đúng là thứ CI chạy (`scripts/*.sh`), nên chạy tay cũng được.

```bash
# backend, một stack, không cần trình duyệt (seed mini-eats, rồi DB + API + TheMealDB)
bash scripts/run-be.sh node       # hoặc: python

# bốn màn app (tự cài chromium)
bash scripts/run-fe.sh node       # hoặc: python

# cả bộ, rồi verify hình dạng lượt chạy so với baseline
bash scripts/gate.sh node
```

Chạy tay từng tầng:

```bash
( cd services/mini-eats && bash serve.sh up )    # service seed mới
cd node && QA_DOMAIN_ROOT=.. npx cucumber-js --tags "@be and @minieats"
```

Yêu cầu: Node ≥ 22.13 (cho `node:sqlite`) và Python ≥ 3.11. Script FE tự cài trình
duyệt. Có sẵn devcontainer đủ bộ trong
[.devcontainer/](.devcontainer/devcontainer.json).

## Bố cục

```
core/            một lõi chấm điểm/hàng đợi/báo cáo/bugflow, vendored vào repo này
services/
  mini-eats/     SQLite + REST + HTML — nền tảng được kiểm (bốn app)
features/        một bộ Gherkin, dùng chung cả hai stack
fixtures/        testcases.json (ID) · expected-results.json (hình dạng)
node/  python/   hai stack: be/{db,api} fe/ui
testcases/       catalogue sinh từ features (không bao giờ lệch)
scripts/         đúng các lệnh CI chạy; tái lập được bằng tay
docs/            luật chấm điểm, quy ước Gherkin, định dạng hàng đợi
.github/workflows/ci.yml
```

## Ghi chú

- Tầng DB kiểm theo **delta** (ghi lại tồn kho, tác động, xem gì đổi), và mỗi
  scenario tự dựng khách/giỏ/đơn mới, nên độc lập với thứ tự chạy mà không cần reset.
- Vòng đời được kiểm từ ba phía: tầng API lái các chuyển trạng thái và assert cổng
  vai trò cùng mã lỗi; tầng DB đọc thẳng audit `order_events` và `ledger` giao hàng;
  tầng FE đọc bảng cửa hàng, bảng tài xế và trang admin rồi đối chiếu với cùng các dòng.
- Catalogue (`fixtures/testcases.json` và `testcases/TestCases.md`) được sinh từ
  các file feature bởi `testcases/build.js`, nên không thể lệch khỏi thứ thực sự
  chạy — CI kiểm bằng `--check`.

## Phạm vi trung thực

Tầng API nguồn-live (TheMealDB) phụ thuộc bên thứ ba có thể chậm hoặc giới hạn
tần suất; các case đó được viết để chấm **Blocked**, không phải Failed, khi điều
đó xảy ra. Service mini-eats tự viết thì hoàn toàn tất định và là nơi kiểm các
đường ghi, máy trạng thái, database và các bất biến khó hơn.
