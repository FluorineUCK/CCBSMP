# CCBSMP

CCBSMP 整合包源码与发布管理仓库。目标远端：私有 GitHub 仓库 fluorineuck/CCBSMP。

## 当前状态

仓库初始化阶段。现有测试实例位于 `D:/CCBSMP/run/versions/CCBSMP Test`，不是此仓库的自动发布源。
尚未导入完整模组锁文件、配置或构建流程；本仓库目前不能重建整合包。

## 目录

- `overrides/common`：双端受控内容。
- `overrides/client`：客户端专用内容。
- `overrides/server`：服务端专用内容，禁止进入客户端发布集。
- `defaults/client`：首次安装的默认偏好。
- `patches`：补丁及适用版本说明。
- `deploy`：不含凭据的部署模板。
- `scripts`：后续构建、验证和发布工具。
- `docs`：管理方案与更新记录。

## 工作约定

1. `main` 保存审核后的变更，开发使用短期 `update/*` 分支。
2. 发布候选如 `1.1.0-rc.1`；正式验证后创建 `v1.1.0` 标签，不覆盖既有发布版本。
3. 模组以版本、来源、安装端与哈希锁定；第三方 JAR 和生成包不提交 Git。
4. 世界、玩家数据、认证数据库、凭据及个人设置不入库。
5. Git push 不部署、不重启服务器。世界备份与 Git 历史分别管理。
6. 提交前检查 `git diff --cached`；`.gitignore` 不是凭据审查的替代品。

## 下一步

核对并导入当前 Test 模组清单，建立下载锁和受控配置，再实现干净目录重建与发布校验。
