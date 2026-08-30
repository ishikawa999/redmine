# Implementation Gap Analysis: personal-pins

## 1. Analysis Context

- **Specification phase**: requirements-generated
- **Requirements approval**: approved
- **Target language**: ja
- **Analysis basis**: 承認済み要件、現在の作業ツリー、Redmine既存の認証認可・メニュー・レスポンシブ・Version実装
- **Steering availability**: `.kiro/steering/` は空。プロジェクト共通方針は取得できないため、既存コード規約とspecのbriefを根拠とした
- **External dependencies**: 追加しない方針のため、外部依存の互換性調査は不要

## 2. Current State

### Existing personal-pins assets

- `Pin`モデルはユーザー所有、ポリモーフィック対象、一意性検証、作成日時降順、対象の`visible?`への委譲を持つ
- `pins`テーブルはユーザー・対象種別・対象IDとtimestampsを持ち、3列の複合一意制約がある
- User、Issue、WikiPageには関連ピンの削除連動がある
- `PinsController`はログイン必須で、一覧・追加・解除、所有者スコープ、許可対象種別チェック、HTML/JS応答を持つ
- IssueとWikiPageの詳細画面に追加・解除操作がある
- 一覧画面には種別、現在の名称、プロジェクト、対象リンク、解除操作、空状態がある
- 英語・日本語の基本文言と、モデル・コントローラ・メニューの初期テストがある

### Reusable Redmine assets

- `Issue#visible?`、`WikiPage#visible?`、`Version#visible?`を対象別の認可判断に再利用できる
- `Version#visible?`は所有プロジェクトに対する`view_issues`で判断するため、共有先ロードマップに表示されるだけのVersionを除外できる
- `:top_menu`にはMy pageがあり、ログイン時のみ表示するメニュー項目を追加できる
- レスポンシブ処理はtop menuの一般メニューを小画面用flyoutへ移動する
- Stimulus/importmap基盤、汎用dropdownの見た目、ユーザー操作後に非同期取得する既存パターンがある

## 3. Requirement-to-Asset Map

| Requirement area | Status | Existing assets | Gap / constraint |
|---|---|---|---|
| 1. 利用者と所有権 | Mostly Existing | `before_action :require_login`、`User.current.pins`起点の一覧・解除、独立したPin関連 | 他ユーザーのPin解除を404にする専用テストがない |
| 2. ピン留めの追加 | Partial | Issue/Wiki詳細の操作、対象`visible?`確認、許可種別チェック、JS/HTML応答 | Versionが許可対象・関連・詳細UI・helper分岐にない。並行追加時の競合を確実に成功扱いにする処理とテストが不足 |
| 3. ピン留めの解除 | Partial | 詳細/一覧からのDELETE、成功後のトグル再描画 | 解除済みPinの再解除は現在404。逐次・並行解除を成功扱いにする設計とテストが不足 |
| 4. 一覧と再訪 | Partial | 全件一覧、最近順、Issue/Wikiの現在情報、空状態 | Version表示・リンクなし。導線がaccount menuにありtop menuではない。最新5件プレビュー、loading/empty/error、focus、同一ページ再表示が未実装 |
| 5. 権限変更と対象変化 | Mostly Existing / Partial | 一覧時の現在権限評価、不可視Pin保持、権限回復時再表示、孤児除外、現在情報参照 | Version未対応。closed/locked/shared Version、closed/archive projectの専用テストが不足 |
| 6. 重複操作と利用環境 | Partial | DB一意制約、逐次重複追加テスト、HTML redirect、英日基本文言 | 真の並行競合、冪等解除、top/general mobile導線、preview遅延取得・失敗隔離、preview文言、性能テストが不足 |

## 4. Detailed Gaps

### 4.1 Domain and persistence

1. **Version対象の欠落 — Missing**
   - 許可対象はIssueとWikiPageだけ
   - Versionに関連ピンの削除連動がない
   - helperはVersionのpath、label、typeを解決できない
   - Version fixtureおよびpin fixtureがない

2. **追加操作の並行安全性 — Partial**
   - DB一意制約は正しい
   - 現在の追加処理は事前検索後作成の競合で一意制約例外がユーザーへ露出する可能性がある
   - 逐次重複はテスト済みだが、並行追加は未検証

3. **解除操作の冪等性 — Missing**
   - 現在は所有者スコープでPinが見つからなければ404
   - 他人のPinを非開示にする要件と、解除済みを成功扱いにする要件を両立する識別方法が必要

4. **ポリモーフィック孤児 — Constraint**
   - 対象側外部キーは設定できない
   - 通常のモデル削除は関連削除で対応可能
   - 直接SQL等による孤児は対象の存在確認で安全に除外する必要がある

### 4.2 Authorization and visibility

1. **対象固有の認可は再利用可能 — Existing**
   - 追加時と一覧時に各対象の`visible?`を使う現在の方向は要件に整合する

2. **Version共有の境界 — Reusable / Test Gap**
   - `Version#visible?`は所有プロジェクト基準なので、共有先で見えるだけのVersionを除外できる
   - locked/closed Versionは閲覧可能であり、状態だけで除外しない
   - closed projectは読み取り可能、archived projectは不可視となる既存挙動に合わせる

3. **不可視Pinの保持 — Existing**
   - 現在の一覧フィルタはPinを削除しないため、権限回復後の再表示を満たす

### 4.3 Navigation and preview UI

1. **メニュー位置 — Missing**
   - 現在はaccount menuに登録されている
   - 要件はtop menuのMy page直後であり、account menuからの削除とtop menuへの追加が必要

2. **hover/focus preview — Missing**
   - preview用の取得経路、レスポンス、partial、表示コンテナ、クライアント制御、CSSがない
   - 汎用dropdownはclick開閉だけで、hover、focus、fetch、状態保持を持たない
   - キーボードfocus、pointer離脱、focus離脱、Escapeなどの操作境界を設計する必要がある

3. **preview states — Missing**
   - loading、preview empty、errorの表示と英日文言がない
   - 失敗時も親リンクによる全一覧遷移を維持する必要がある

4. **small-screen behavior — Partial**
   - top menuへ正しく登録すれば既存処理が一般flyoutへ移動する
   - 小画面ではpreviewを抑止し、tapを一覧遷移として維持する判定が必要

### 4.4 Performance

1. **初期ページ描画 — Existing baseline / Constraint**
   - 現在のbase layoutはPinを取得しないため、初期描画にPin queryはない
   - preview内容をサーバー側でbase layoutへ埋め込むと要件に反する
   - ユーザーがhover/focusするまで取得を開始しない必要がある

2. **可視な最新5件の取得 — Research Needed**
   - 現在の`visible_pins`はユーザーの全Pinを読み込み、Rubyで可視性を評価する
   - 単純に先頭5件を取得してから不可視項目を除くと、閲覧可能な最新5件を満たせない
   - `includes(:pinnable)`だけでは対象のprojectまで十分に先読みできず、型別の認可でN+1余地がある

3. **同一ページ内の再表示 — Missing**
   - 取得済みpreviewを保持する仕組みがない
   - Pinの追加・解除後には保持内容を失効または更新する必要がある

4. **性能検証 — Missing**
   - 通常ページ初期表示でpreview request/queryが発生しないことを検証するテストがない
   - previewのquery budget、候補走査上限、件数増加時の振る舞いは未決定

### 4.5 Progressive enhancement

- ControllerはHTML redirectを持つが、現在の`remote`かつmethod付きlinkがクライアント機能なしで確実にPOST/DELETEになるかは要確認
- 通常ページ遷移だけで追加・解除できるフォームまたはリンクの方式を設計段階で確認する必要がある

### 4.6 Test gaps

- Versionの追加・解除・一覧・権限・共有・locked/closed・削除
- 不可視対象の追加拒否、権限喪失/回復、他人のPin解除非開示
- 解除済み再解除、再Pin時の先頭移動、並行追加・並行解除
- 通常ページ遷移による追加・解除
- top menuの位置と順序、account menuからの削除
- previewの最大5件、最近順、不可視除外、対象リンク、loading/empty/error、同一ページ再表示
- keyboard focus、Escape、pointer/focus離脱
- 小画面での一般flyout移動とpreview抑止
- preview取得が通常ページ初期描画へquery/requestを追加しないこと
- 英語・日本語のpreview文言

## 5. Implementation Approach Options

### Option A: Existing-component extension

**Outline**

- Pin/Controller/HelperをVersionまで拡張
- top menuへ項目を移動
- 既存dropdown controllerへhover、focus、非同期取得、状態保持を追加

**Advantages**

- 新規ファイルが少ない
- 既存のdropdown外観とmenu infrastructureを直接利用できる

**Disadvantages / Risks**

- 汎用dropdownの責務が増え、プロフィールメニューなど既存利用箇所へ回帰リスクがある
- pointer、keyboard、mobile、fetch状態が一つの汎用controllerへ混在する
- preview性能問題は別途解決が必要

### Option B: New isolated pin navigation component

**Outline**

- Pinの基本モデルは再利用
- top menu item、preview取得、preview partial、専用クライアント制御を新規コンポーネントとして分離
- 全件一覧とは別の読み取り経路を持つ

**Advantages**

- previewの責務、状態、性能、テストを隔離できる
- 既存dropdownへの影響が小さい
- 将来のpreview UI変更が局所化する

**Disadvantages / Risks**

- MenuManagerが生成する標準`li > a`へpreview用DOM/data属性を安全に組み込む拡張点の確認が必要
- ファイル数と新しいインターフェースが増える
- Pin CRUDとの状態同期を明示的に設計する必要がある

### Option C: Hybrid

**Outline**

- Pinモデル、CRUD Controller、Helper、一覧は既存実装を拡張してVersionと冪等性へ対応
- top menu登録は既存MenuManagerを利用
- previewの取得・partial・クライアント制御だけを専用コンポーネントへ分離
- 小画面では親リンクを通常遷移として維持し、preview制御を無効化

**Advantages**

- 既存CRUD資産を活かしながら、性能とUI状態を隔離できる
- 既存dropdown利用箇所への回帰リスクを抑えられる
- 要件ごとのテスト境界が明確

**Disadvantages / Risks**

- 既存拡張と新規コンポーネントの接続設計が必要
- MenuManager、preview、Pin CRUD間の状態失効ルールが必要
- Option Aより実装計画がやや複雑

## 6. Complexity and Risk

- **Effort: M (3–7 days)** — CRUD基盤は存在するが、Version、メニュー統合、accessible preview、性能・並行性・responsiveテストが追加範囲
- **Risk: Medium** — 対象認可は既存APIを再利用可能。主な不確実性は可視な最新5件の効率的取得、MenuManagerへのpreview DOM統合、冪等解除の識別、mobile/focus操作

## 7. Design-phase Recommendations

以下は設計フェーズで比較・決定すべき事項であり、本分析では最終決定しない。

1. **Candidate direction**: Option Cは既存資産の再利用とpreview責務の分離のバランスが良い
2. **Visible latest-five strategy**:
   - 対象種別ごとのvisible scopeを統合して並び替える
   - 一定件数ずつ候補を追加取得し、閲覧可能5件になるまで安全な上限内で走査する
   - 全件取得後にRubyで評価する（単純だが件数増加に弱い）
3. **Menu integration**: MenuManager itemへwrapper、preview container、data属性を組み込む拡張方法
4. **Preview contract**: HTML partialか構造化レスポンスか、loading/empty/errorの責任分担
5. **Responsive behavior**: 既存breakpointと同じ条件でpreviewを無効化する方法
6. **Idempotent destroy**: 他人のPinを非開示にしつつ、解除済み対象を成功扱いにする入力契約
7. **Progressive enhancement**: クライアント機能なしでもPOST/DELETEを成立させる操作表現
8. **Cache invalidation**: 同一ページでPin追加・解除後にpreview内容を更新または失効する方法
9. **Performance budget**: 初期ページはPin queryゼロ、previewはbounded query/scanとするかを設計で明文化

## 8. Research Needed

- MenuManagerが標準menu nodeへ任意wrapper/partial/data属性を安全に組み込めるか。難しい場合の専用top-menu partial挿入位置
- 複数ポリモーフィック型に対し、権限漏えいなく可視な最新5件をbounded costで得る最適なRedmine流パターン
- Redmineのresponsive breakpointを新しいクライアント制御と共有する方法
- system testでhover、focus、mobile、preview fetch失敗を安定して検証する既存fixture/helper
- 現在のUJS依存リンクが、即時更新を利用できない環境で要件6.3を満たす範囲

## 9. Design Discovery Update

### Summary

- 軽量ディスカバリーにより、既存CRUDを拡張しpreviewだけを分離するHybridを採用した。
- MenuManagerの標準nodeはanchorのHTML属性は持つが`li` wrapper内の任意fragmentを表現しないため、`:pinned_items`専用のmenu rendererを設ける。
- responsive.jsはtop menuの`ul`全体をflyoutへ移送する。preview wrapperを同じ`li`内に置き、mobile時は既存toggle可視性を使ってfetchを抑止する。

### Design Decisions

1. **可視読み取りの一般化**: 一覧とpreviewを`Pin::VisibleReader`の`limit`差として統一する。previewは最近順キーセット・バッチ走査を行い、固定候補上限による5件欠落を許さない。
2. **Build vs Adopt**: 認可、MenuManager、Stimulus、UJS、responsive flyoutを採用する。汎用dropdownの拡張は既存利用箇所への責務漏れになるため、pin preview controllerだけを新設する。
3. **冪等解除**: Pin IDではなく許可済みtarget identityを入力とし、現在ユーザーscopeの0件削除も成功とする。これにより他ユーザーのPin存在を観測させない。
4. **Progressive enhancement**: 操作は通常HTMLフォーム契約を基礎とし、UJSは同じendpointのJS応答による即時更新だけを追加する。
5. **キャッシュ境界**: preview HTMLはStimulus instance内だけで保持し、Pin変更イベントで失効する。サーバー共有cacheは権限変化による漏えいリスクと複雑性のため採用しない。

### Resolved Risks

- 初期描画はmenuの静的wrapperだけをrenderし、Pin queryとpreview requestを発生させない。
- Versionの可視性は所有project基準の既存`Version#visible?`に委譲し、共有先表示を権限根拠にしない。
- `.kiro/steering/`は空のため、設計は既存Redmineコード規約と承認済み要件を基準にした。
