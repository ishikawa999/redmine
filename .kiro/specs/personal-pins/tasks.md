# Implementation Plan

- [ ] 1. ピン留めのドメイン基盤を完成させる
- [x] 1.1 対応対象とピン留めの不変条件を拡張する
  - チケット、Wikiページ、バージョンだけを個人用ピンの対象として受け付ける
  - ユーザー・対象種別・対象IDの組み合わせを一意に保ち、作成日時とIDで最近順を確定する
  - ピン留め操作が通知購読、優先順位、担当状態へ作用しない境界を維持する
  - 3種類の許可、重複拒否、最近順、可視性委譲をモデルテストで確認できる状態にする
  - _Requirements: 1.1, 1.4, 2.5, 4.6, 5.2, 6.1_
  - _Boundary: Pin_

- [x] 1.2 対象モデルとの関連と削除時の整合性を接続する
  - ユーザーと3種類の対象にピン関連を持たせ、通常の対象削除時に対応するピンを消去する
  - バージョンを含むfixtureを整え、既存のユーザー所有関係と競合しないようにする
  - 各対象を削除すると対応Pinだけが削除され、他のPinが残ることをテストで観測可能にする
  - _Depends: 1.1_
  - _Requirements: 1.1, 1.4, 5.2, 5.4_
  - _Boundary: Domain Integration_

- [ ] 1.3 現在閲覧可能なピンを最近順で取得する読み取り境界を作る
  - 一覧向け全件取得とプレビュー向け上限付き取得を同じ可視読み取り契約で提供する
  - 最近順のキーセット・バッチ走査と型別先読みで、不可視項目が続いても閲覧可能な最新5件を欠落させない
  - 権限喪失中のPinを保持し、権限回復時に再表示し、削除済み対象は安全に除外する
  - 現在の名称・プロジェクト・状態、終了済み対象、閉鎖済みプロジェクト、共有Versionの所有project権限を既存認可で評価する
  - 不可視候補がバッチ境界を跨ぐケースでも、可視な最新5件が順序どおり返ることを単体テストで確認可能にする
  - _Depends: 1.2_
  - _Requirements: 4.2, 4.8, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  - _Boundary: VisibleReader_

- [ ] 2. 認証済みの読み書き契約を完成させる
- [ ] 2.1 対象identityによる冪等な追加・解除APIを実装する
  - ログイン、許可対象種別、対象存在、現在の閲覧権限を順に検証する
  - 同時追加による一意制約競合を既存Pinの成功として正規化し、最終件数を1件に収束させる
  - 解除は現在ユーザーと対象identityで限定し、0件削除も成功として他ユーザーのPin存在を開示しない
  - HTMLでは安全な遷移元へ戻し、JSでは後続の表示更新が選択できる応答を返す
  - 正常・不正型・不可視・重複・反復操作の応答と最終件数0または1を機能テストで観測可能にする
  - _Depends: 1.2_
  - _Requirements: 1.1, 1.2, 1.3, 2.2, 2.4, 2.5, 3.2, 3.4, 6.1, 6.2, 6.3_
  - _Boundary: PinsController Write API_

- [ ] 2.2 一覧とプレビューの読み取りAPIを実装する
  - ログインユーザーの一覧と最大5件のプレビューを可視読み取り境界から取得する
  - 一覧用の通常画面とプレビュー用HTML fragmentを分離し、preview障害が通常画面へ伝播しない経路にする
  - 未ログイン、空状態、不可視・削除済み対象、最大件数を機能テストで確認する
  - 一覧は全可視Pin、previewは最近順5件以下の割当を返すことを観測可能にする
  - _Depends: 1.3, 2.1_
  - _Requirements: 1.1, 1.2, 4.2, 4.8, 4.11, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.6, 6.7_
  - _Boundary: PinsController Read API_

- [ ] 3. 対象情報と詳細画面の操作を統合する
- [ ] 3.1 3種類の表示情報と一覧・プレビュー表示を作る
  - 対象種別ごとに現在の名称、現在のproject、対象URL、種別ラベルを一貫して解決する
  - 一覧行と最大5件のpreview fragmentに直接リンクを表示し、表示可能な項目がない場合は空状態を示す
  - 読み込み中・空・取得失敗を含む英語・日本語文言を追加する
  - helper/viewテストで3種類の現在情報、escape済みリンク、英日状態表示を確認可能にする
  - _Depends: 2.2_
  - _Requirements: 2.1, 3.1, 4.3, 4.4, 4.5, 4.9, 4.10, 4.11, 4.12, 5.5, 6.4_
  - _Boundary: PinsHelper, PinViews_

- [ ] 3.2 各詳細画面へ追加・解除操作を接続する
  - チケット、Wikiページ、バージョンの詳細画面だけに現在状態に合う操作を表示する
  - 通常HTMLフォームで追加・解除と再描画を成立させ、JS応答ではtoggleを即時更新する
  - Pin変更後に同一ページのpreviewキャッシュを失効させるイベントを発行する
  - Versionロードマップには操作が存在せず、3種類の詳細では追加後に解除、解除後に追加が表示されることを確認可能にする
  - _Depends: 2.1, 3.1_
  - _Requirements: 2.1, 2.2, 2.3, 2.6, 3.1, 3.2, 3.3, 6.3_
  - _Boundary: Detail Integration_

- [ ] 4. トップナビゲーションと遅延プレビューを統合する
- [ ] 4.1 ピン導線をトップメニューのマイページ直後へ配置する
  - account menuから既存導線を除き、ログイン時だけtop menuのMy page直後へ登録する
  - ピン項目だけに専用wrapperとpreview領域を与え、標準MenuManagerの他項目へ影響させない
  - 既存responsive移送後も一般flyout内で通常の一覧リンクとして機能するDOM契約にする
  - menu/helperテストでdesktopとmobileの順序、guest非表示、一覧URLを観測可能にする
  - _Depends: 3.1_
  - _Requirements: 4.1, 4.7, 6.5, 6.6_
  - _Boundary: Navigation Integration_

- [ ] 4.2 hover・focus対応のプレビュー状態管理を実装する
  - pointer enterとfocus inでdesktopだけpreviewを開き、idle時だけ取得を開始する
  - loading、loaded、empty、errorを領域内で切り替え、取得済み内容は同じページで再利用する
  - pointer/focus離脱とEscapeで閉じ、内部移動では閉じず、親リンクとpreview内リンクの通常遷移を妨げない
  - mobileでは取得と開閉処理を抑止し、変更イベントではcacheを次回表示まで失効する
  - 状態fixtureまたはシステム観測で、2回目のopenに追加取得がなく、error時も親リンクが使える状態にする
  - _Depends: 2.2, 4.1_
  - _Requirements: 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 6.5, 6.6, 6.7_
  - _Boundary: PinPreviewController_

- [ ] 4.3 ナビゲーションとpreviewの各境界を結合する
  - menu wrapper、遅延取得endpoint、fragment、クライアント状態、専用styleを接続する
  - desktopの親導線は一覧へ、preview項目は対象へ直接遷移し、mobileの導線はpreviewなしで一覧へ遷移させる
  - 通常ページ初期描画はPin内容を問い合わせず、preview取得失敗時も現在ページを維持する
  - 実画面でdesktop hover/focusとmobile clickの両経路が成立することを確認可能にする
  - _Depends: 3.1, 4.2_
  - _Requirements: 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 6.5, 6.6, 6.7_
  - _Boundary: Preview Integration_

- [ ] 5. 受け入れフローと回帰を検証する
- [ ] 5.1 詳細操作・一覧・通常遷移のE2Eを検証する
  - 3種類の詳細で追加・解除し、一覧で現在情報を確認して対象へ再訪する流れを検証する
  - 解除後の再Pinが先頭になること、他人のPinが操作・表示されないこと、通知等が変化しないことを検証する
  - JavaScriptを介さない追加・解除・一覧アクセスと、ロードマップにVersion操作がないことを検証する
  - 詳細・一覧のfocused system scenariosがすべて成功する状態にする
  - _Depends: 3.2, 4.3_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.5, 6.3, 6.4_
  - _Boundary: System Validation Detail and List_

- [ ] 5.2 desktopプレビューの操作性と障害耐性をE2E検証する
  - pointerとkeyboard focusによるloadingからsuccess/empty/errorへの遷移を検証する
  - 最新5件の順序、対象への直接遷移、Escapeと離脱、親一覧リンクを検証する
  - 同一ページでの再表示が再取得せず、Pin変更後だけ再取得することを検証する
  - previewのfocused system scenariosがすべて成功し、2回目openのrequest数が増えない状態にする
  - _Depends: 5.1_
  - _Requirements: 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 6.6, 6.7_
  - _Boundary: System Validation Preview_

- [ ] 5.3 mobile・権限変化・性能境界をE2E検証する
  - 小画面flyoutではpreview取得なしで一覧へ直接遷移することを検証する
  - 通常画面初期表示にpreview requestとPin内容queryがなく、preview障害時も通常操作できることを検証する
  - 権限喪失・回復、対象削除、終了・ロック状態、閉鎖project、共有Version所有project不可視を検証する
  - mobile、security、performanceのfocused scenariosとquery/request assertionsが成功する状態にする
  - _Depends: 5.2_
  - _Requirements: 1.2, 1.3, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.5, 6.6, 6.7_
  - _Boundary: System Validation Nonfunctional_

- [ ] 5.4 関連領域の回帰と最終整合性を確認する
  - Pinのunit/helper/controller/systemテストとIssue、Wiki、Version、layout、responsive menuの関連suiteを実行する
  - DB一意性、route、locale、asset import、HTML/JS応答の統合に未検出の回帰がないことを確認する
  - 差分検査を行い、新規migrationおよび既存migration適用後schemaとの差分がない状態にする
  - 関連テストが成功し、全41要件の実装経路がタスク成果物から追跡可能な状態にする
  - _Depends: 5.3_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  - _Boundary: Regression Validation_
