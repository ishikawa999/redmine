# Requirements Document

## Introduction

Redmineを日常的に利用するユーザーが、頻繁に参照するチケット、Wikiページ、バージョンを個人用にピン留めし、プロジェクト一覧、検索、ロードマップを経由せず再訪できるようにする。ピン留めは通知購読とは独立した個人のナビゲーション機能とし、対象に対する現在の閲覧権限を尊重する。

## Boundary Context

- **In scope**: チケット、Wikiページ、バージョンの個人ピン留め、各詳細画面での追加・解除、トップメニューからの一覧アクセスと最大5件のプレビュー、最近ピン留めした順の表示、権限変化と対象削除への安全な対応、日本語・英語の表示
- **Out of scope**: 通知、共有ピン、チームまたはプロジェクト共通ピン、手動並び替え、分類、既存のプロジェクトブックマークやWatcherとの統合、外部システム連携、管理者向け管理画面
- **Adjacent expectations**: 対象の閲覧可否と対象へアクセスした際の拒否動作は、チケット、Wikiページ、およびバージョンの既存権限制御に従う。バージョンが別プロジェクトのロードマップに共有表示されることだけではピン留め可能としない。ピン留め操作は既存の通知購読状態、優先順位、担当状態を変更しない

## Requirements

### Requirement 1: 利用者と所有権

**Objective:** As a ログインユーザー, I want 自分専用のピン留めを利用する, so that 他のユーザーと混同せず参照先を管理できる

#### Acceptance Criteria

1. While ユーザーがログインしている, the Personal Pins機能 shall そのユーザー自身のピン留めだけを表示および操作可能にする
2. If ログインしていない利用者がピン留め一覧または操作へアクセスする, the Personal Pins機能 shall ログインを要求する
3. If ユーザーが他のユーザーに属するピン留めの解除を試みる, the Personal Pins機能 shall 対象の存在を開示せず操作を拒否する
4. The Personal Pins機能 shall ピン留めによって対象の通知購読、優先順位、担当状態を変更しない

### Requirement 2: ピン留めの追加

**Objective:** As a ログインユーザー, I want 閲覧中の項目をその場でピン留めする, so that 後から素早く再訪できる

#### Acceptance Criteria

1. While ユーザーが閲覧可能なチケット、Wikiページ、またはバージョンの詳細を表示している, the Personal Pins機能 shall ピン留め操作を提示する
2. When ユーザーがピン留め操作を実行する, the Personal Pins機能 shall 対象をそのユーザーのピン留め一覧へ追加する
3. When ピン留めが完了する, the Personal Pins機能 shall 詳細画面の操作表示をピン留め解除可能な状態へ更新する
4. If ユーザーが閲覧できない対象のピン留めを試みる, the Personal Pins機能 shall ピン留めを作成せずアクセスを拒否する
5. If 対応対象ではない種類の項目が指定される, the Personal Pins機能 shall ピン留めを作成せず対象外として扱う
6. While ユーザーがロードマップを表示している, the Personal Pins機能 shall バージョンのピン留め操作をロードマップ上に表示しない

### Requirement 3: ピン留めの解除

**Objective:** As a ログインユーザー, I want 不要になったピン留めを気軽に解除する, so that 一覧を自分に必要な項目だけに保てる

#### Acceptance Criteria

1. While 対象がそのユーザーにピン留めされている, the Personal Pins機能 shall 詳細画面にピン留め解除操作を提示する
2. When ユーザーが詳細画面または一覧から解除操作を実行する, the Personal Pins機能 shall そのユーザーのピン留めから対象を除外する
3. When 詳細画面で解除が完了する, the Personal Pins機能 shall 操作表示を再びピン留め可能な状態へ更新する
4. If 解除対象がすでに解除済みである, the Personal Pins機能 shall 操作を成功扱いとしエラー画面を表示しない

### Requirement 4: 一覧と再訪

**Objective:** As a ログインユーザー, I want ピン留めした項目を一か所で確認する, so that よく見る項目へ簡単にアクセスできる

#### Acceptance Criteria

1. While ユーザーがログインしている, the Personal Pins機能 shall トップメニューのマイページ直後にピン留め一覧への導線を表示する
2. When ユーザーがピン留め一覧を開く, the Personal Pins機能 shall 閲覧可能なピン留めを最近ピン留めした順に表示する
3. The Personal Pins機能 shall 各一覧項目に対象の種類、現在の名称、現在のプロジェクト、および対象へのリンクを表示する
4. When ユーザーが一覧項目のリンクを選択する, the Personal Pins機能 shall 対応するチケット、Wikiページ、またはバージョンへ移動させる
5. If 表示可能なピン留めがない, the Personal Pins機能 shall ピン留めがないことを示す空状態を表示する
6. When ユーザーがピン留めを解除した後に同じ対象を再度ピン留めする, the Personal Pins機能 shall その対象を一覧の先頭に表示する
7. When ユーザーがトップメニューのピン留め導線を選択する, the Personal Pins機能 shall ピン留め一覧画面へ移動させる
8. While ポインターでピン留め導線を指しているかキーボードフォーカスが当たっている, the Personal Pins機能 shall 閲覧可能なピン留めを最近ピン留めした順に最大5件プレビュー表示する
9. When ユーザーがプレビュー項目を選択する, the Personal Pins機能 shall 対応するチケット、Wikiページ、またはバージョンへ直接移動させる
10. While プレビュー内容を取得している, the Personal Pins機能 shall プレビュー領域に読み込み中であることを表示する
11. If プレビューに表示可能なピン留めがない, the Personal Pins機能 shall プレビュー領域にピン留めがないことを表示する
12. If プレビュー内容を取得できない, the Personal Pins機能 shall 現在の画面とピン留め一覧への導線を利用可能なまま保ち、プレビュー領域に取得できなかったことを表示する
13. When 同じ画面で取得済みのプレビューを再び表示する, the Personal Pins機能 shall 追加の読み込み完了を待たずに同じ内容を表示する

### Requirement 5: 権限変更と対象の変化

**Objective:** As a ユーザー, I want 現在閲覧できる項目だけが一覧に現れる, so that 権限を尊重しながらピン留めを継続利用できる

#### Acceptance Criteria

1. If ピン留めした対象の閲覧権限をユーザーが失う, the Personal Pins機能 shall 対象の名称、プロジェクト、およびリンクを一覧に表示しない
2. While ピン留めした対象が閲覧不能である, the Personal Pins機能 shall ピン留め状態を保持する
3. When ユーザーが対象の閲覧権限を再び得る, the Personal Pins機能 shall 保持していた対象を一覧へ再表示する
4. If ピン留めした対象が削除されている, the Personal Pins機能 shall その対象を一覧に表示せず、一覧表示をエラーにしない
5. When ピン留めした対象の名称、所属プロジェクト、または状態が変更される, the Personal Pins機能 shall 一覧に対象の現在の情報を表示する
6. While チケット、Wikiページ、またはバージョンが既存の権限制御で閲覧可能である, the Personal Pins機能 shall 終了済みチケット、ロック済みまたは終了済みバージョン、もしくは閉鎖済みプロジェクトであることだけを理由に対象を除外しない
7. If バージョンが共有先プロジェクトのロードマップに表示されていても所有プロジェクトを閲覧できない, the Personal Pins機能 shall そのバージョンをピン留め可能にせず、既存のピンも一覧に表示しない

### Requirement 6: 重複操作と利用環境

**Objective:** As a ログインユーザー, I want 反復操作や通常の利用環境でも安定してピン留めを使う, so that 操作状態を意識せず利用できる

#### Acceptance Criteria

1. If 同じユーザーが同じ対象を繰り返しまたは同時にピン留めする, the Personal Pins機能 shall 操作を成功扱いとし一覧には1件だけ表示する
2. If 同じピン留めに対する解除操作が繰り返しまたは同時に行われる, the Personal Pins機能 shall 最終状態を解除済みにしエラー画面を表示しない
3. While ページ内の即時更新が利用できない, the Personal Pins機能 shall 通常のページ遷移によってピン留めの追加、解除、および一覧へのアクセスを利用可能にする
4. Where 日本語または英語の表示言語が選択されている, the Personal Pins機能 shall 操作名と空状態を選択言語で表示する
5. While 小画面向けのナビゲーションが表示されている, the Personal Pins機能 shall 一般ナビゲーション内にピン留め導線を表示し、選択時にプレビューを介さず一覧画面へ移動させる
6. While 通常画面を最初に表示している, the Personal Pins機能 shall ピン留めプレビュー内容の取得完了を待たずに画面を表示する
7. If ピン留めプレビュー内容の取得に失敗する, the Personal Pins機能 shall 通常画面の表示と操作に失敗の影響を与えない
