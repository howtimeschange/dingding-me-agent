# Runtime 状态与人工回查

0.2.0 持久化接收事件、步骤结果与普通回复投递状态。它能阻止已知中断动作被盲目
重复执行；对于尚无法确认的外部结果，会保留 unknown 并停止相关任务。当前没有
恢复 CLI，没有自动远端对账，也没有“重试所有失败任务”命令。

## 先确认同一个状态目录

```bash
dingding-me-agent --runtime-status

# 若服务使用自定义数据库，必须查同一条路径。
dingding-me-agent --runtime-db /ABS/PATH/TO/runtime.sqlite3 --runtime-status
```

命令以只读模式打开已有数据库，输出 jobs/steps/outbox 按 status 的计数以及 failed /
blocked job ID；数据库不存在时只输出 `exists=false`。它不启动 DWS、执行模型、
获取服务锁、迁移表或修改恢复状态。数据库路径优先取 `--runtime-db`，否则对
`--state-file` 执行 `.with_suffix(".sqlite3")`。默认是 `~/.dingding-me-agent/seen.sqlite3`。

状态文件含业务上下文，应保留在私有目录。数据库文件权限为 0600；使用 WAL 和
FULL 同步。不要仅复制活动数据库主文件作完整备份，忽略仍在使用的 WAL 文件。

## 状态分别表示什么

| 对象 | 状态 | 含义 |
| --- | --- | --- |
| job | queued / running / completed | 收件箱排队、处理中、handler 已返回；completed 不等于代码已验证或已发布 |
| job | blocked | 路由未注册或排队时授权快照与当前配置不符 |
| job | failed | handler 抛出错误，包含需要人工回查的情况；不自动重试 |
| step | started / completed | 执行已开始 / 已保存可复用结果 |
| step | unknown | 不能确认该步骤的最终结果，禁止自动再次执行 |
| outbox | queued / sending / sent | 普通回复待发送 / 发送中 / 已记录有效回执 |
| outbox | unknown | 缺少确认结果，禁止自动重发 |

启动会将 running job 重新排队、started step 变为 unknown、sending outbox 变为
unknown。恢复后的 job 仍需通过当前路由和策略核对；触及 unknown 步骤或回复会
退出处理并记录 attention，不会靠从头执行来补齐结果。

completed 检查点可复用；sent 回复可复用已记录回执。同一发送 UUID 不能换正文、
目标或策略后继续使用。这些机制不保证 shell、模型或全部外部系统的动作只发生一次。

## 人工回查顺序

1. 保存当前 job/step/发送 UUID、群和任务 ID；核对 `runtime_attention_required`
   及对应 task bundle。只在授权范围内查看业务上下文，不公开日志原文或凭据。
2. **发送结果未知**：先从钉钉权威消息读回或服务端记录确认该 UUID/任务对应回复
   是否实际发送、目标是否正确。DWS 超时、无有效 JSON、非成功退出都不能直接证明
   没有发出。只看到本地草稿也不能证明远端没有收到。
3. **代码/模型结果未知**：先检查工作树、Git 状态、任务日志和实际产物；必要时
   只读核对外部系统。已开始但无完成检查点不等于未执行，也不等于已完成。
4. **策略发生变化**：核对原授权快照与当前群/仓库/owner/执行/发送策略；不要仅
   为消除 blocked 而扩大配置。需要新的工作时应明确其范围和与原任务的关系。
5. 整理权威证据后再由维护者设计针对这条记录的恢复操作。目前没有可推荐给用户
   直接执行的通用状态改写或重试命令；不要手动清状态假装结果已确认。

不要删除 seen/SQLite/step/outbox、换新数据库、重新发同一请求或反复回复 OK 来
绕过 unknown。即使已确认未完成，也应先安排有记录、保留原证据的受控恢复，
不能把“没有看到结果”当作新的执行授权。

## 审批、TTL 与交付

同群多个请求通过 `确认 dws-codex-<20位哈希>` 选择。无 ID 确认只适用于唯一请求。
确认正文须由完整配置确认词组成；否定或追问不会作为同意。`code_write_policy=none`
不允许写代码；`approval` 对 AI/Codex 回复引擎都要求先保存请求并等待确认。
第一次开始执行前需要 owner、有效期和原授权范围匹配。恢复不会刷新创建时间。

代码结果已在完成检查点中记录时，等待交付超过 TTL 不会使其重新执行或被丢弃；
仍需策略匹配，并遵守 outbox 的未知结果保护。后续确认复用原任务的执行/投递身份，
不能用于重发未知回复。旧版单请求审批文件仍可读取，不会自动迁移到另一套运行目录。

## Ready 招呼与停机

listener 的 ready/connected 是连接证据；`ready_message` 是可选外发动作，以独立
检查点记录。`ready_message_attention_required` 表示招呼需要回查，服务仍可继续
启动 inbox。这不证明招呼未发，也不证明所有 listener/业务回复健康。

SIGTERM/SIGINT 停止接收并保留 queued；不启动剩余积压任务。运行中的工作可能在
进程等待期间完成，强制杀进程则由下次启动的 unknown 防线保护。数据库锁只保证
同一数据库同时一个 worker，不能阻止两个独立数据库接收同一群而产生重复工作。
