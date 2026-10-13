# Lunaria v0.1.0 手動テスト

## 準備
1. `ensure chat` が有効な環境で `ensure ptech_lunaria_game`
2. `server.cfg` に進行役ACEを設定（例：`add_ace group.admin lunaria.admin allow`）
3. 4人以上で各自 `/ljoin`。進行役は `/lstatus` で確認

## ケース
- [ ] 3人では `/lstart` できず、4人で開始できる
- [ ] 各自に役職が個別通知され、他プレイヤーに見えない
- [ ] 一般プレイヤーが `/lstart`, `/lnext`, `/lreset` を使えない
- [ ] 夜の人狼だけが `/lkill ID` を送信できる
- [ ] 占い師だけが夜に一度 `/linspect ID` を送信できる
- [ ] 夜→昼、昼→夜が進行役の `/lnext` で切り替わる
- [ ] 無効ID・死亡者・自分への不正対象選択を拒否する
- [ ] 昼投票の同数時、処刑が発生しない
- [ ] 生存者数による勝敗が正しく確定する
- [ ] ゲーム中の切断が脱落扱いとなる
- [ ] `/lreset` 後に再募集できる

※ まだFiveM実機での検証・自動テストは未実施。
