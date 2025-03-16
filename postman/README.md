# AINovalWriter API Postman 集合

这个目录包含了AINovalWriter应用的Postman API集合，可以用于测试和开发。

## 导入说明

1. 打开Postman应用
2. 点击左上角的"Import"按钮
3. 选择"File" > "Upload Files"
4. 浏览并选择`AINovalWriter_Auth_API.json`文件
5. 点击"Import"按钮完成导入

## 环境设置

导入集合后，建议创建一个环境来存储变量：

1. 点击右上角的"Environments"下拉菜单
2. 选择"Add"创建新环境
3. 添加以下变量：
   - `base_url`: API的基础URL (例如: `http://localhost:8080`)
   - `jwt_token`: 将自动由集合测试脚本填充
   - `refresh_token`: 将自动由集合测试脚本填充
4. 保存环境并在右上角选择它

## 使用说明

### JWT认证流程

1. 首先调用"登录"或"注册"接口获取JWT令牌
2. 令牌会自动保存到环境变量中
3. 后续需要认证的请求会自动使用保存的令牌
4. 当令牌过期时，可以使用"刷新令牌"接口获取新令牌

### 接口说明

集合包含以下接口：

1. **登录** (`POST /api/v1/auth/login`)
   - 用于用户登录并获取JWT令牌

2. **注册** (`POST /api/v1/auth/register`)
   - 用于新用户注册并获取JWT令牌

3. **刷新令牌** (`POST /api/v1/auth/refresh`)
   - 使用刷新令牌获取新的JWT令牌

4. **修改密码** (`POST /api/v1/auth/change-password`)
   - 修改用户密码，需要JWT认证

## 自动化测试

集合包含测试脚本，会自动：

1. 保存登录/注册后获取的JWT令牌到环境变量
2. 保存刷新后的新JWT令牌到环境变量

这使得可以轻松创建自动化测试流程，无需手动复制令牌。 