# ブラウザーテスト検証の続行

2026-08-31、ユーザーの「続き」により、前回のNO-GOで残ったブラウザーエラー2件の調査を再開した。

## Debug Report

- ROOT_CAUSE: Issue保存と詳細画面応答は成功している。submit直後にCapybaraの`Document#text`が旧documentの`/html`を参照し、画面切替と競合した可能性が高い。Versionケースにはmodalの非同期作成完了を明示確認しない同期不足もある。
- CATEGORY: LOGIC_ERROR
- CONFIDENCE: MEDIUM
- 所有境界: Issueのsystemテスト。Pinの製品コード・既存認可・共通例外処理は変更しない。
- FIX_PLAN:
  1. Watcher付きIssue作成と新Version付きIssue作成のsubmit後、詳細URLへの到達を待機付きassertionで確認してから成功メッセージを検証する。
  2. 新Versionのmodalが閉じ、対象Versionが選択されたことを確認してから、Issueフォーム内のCreateを押す。
- VERIFICATION: 同じseed 18637の全system suite、Issue suite、起動確認で再検証する。
- NEXT_ACTION: RETRY_TASK

## 根拠と限界

- 前回の全system実行は159 tests / 1110 assertions、エラー2件。両エラーはChrome inspectorの`Node with given id does not belong to the document`。
- 保存時ログは`POST /projects/ecookbook/issues → 302 /issues/21 → GET /issues/21 → 200`。保存失敗や詳細画面のサーバーエラーではない。
- 変更前の単独2ケースは2 tests / 22 assertions、同じ2ケースを各8回反復すると16 tests / 176 assertionsで成功。不定期の問題であり、単独成功だけでは解消と判断しない。
- Capybaraのローカル実装で`Document#text → find('/html').text`と可視性判定経路を確認。URL照合はDOM参照を伴わない。[Capybara公式のNavigation説明](https://github.com/teamcapybara/capybara#navigating)も待機付きpath matcherを推奨している。
- Version作成の既存JS応答はmodalを閉じてからselectを差し替える。今回の確認はこの完了条件に対応する。
- 固定sleep、汎用UnknownErrorのretry、例外の握りつぶし、依存ライブラリー変更は行わない。
- 変更後のIssue suite: 27 tests / 255 assertions、失敗・エラー・skipなし、exit 0。RuboCopも成功。
- 独立レビューの全system再実行: `bundle exec rails test:system --seed 18637`、159 tests / 1123 assertions、失敗・エラー・skipなし、exit 0。Review Verdict: APPROVED。
- Chrome自体の欠陥や、今後のすべてのブラウザー不安定性の解消まで断定するものではない。
