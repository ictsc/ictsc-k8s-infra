# Valkey

Valkey + Sentinel + HAProxy による HA Valkey 構成

1Pod のクラッシュ or 1台のノード故障に耐えられるようにしています

## Valkey

Redis 互換の KVS。

スナップショット(RDB)と Append File による永続化を行っています。
Append の fsync が1秒間隔なのでクラッシュした場合は最大1秒ぶんのデータが消失します。

1つ以上のレプリカを持つことをプライマリが正常である条件としているため、プライマリ1台+レプリカ2台の構成を取っています。

## Sentinel

Valkey クラスタを監視し自動フェイルオーバーを行います。Split Brain を防ぐため3台で構成します。

## HAProxy

Sentinel はフェイルオーバーを管理しますがプライマリへのトラフィックのルーティングを行わないため HAProxy を使います。
HAProxy に対して接続することで常にプライマリにコマンドが送られます。
