# Electron-Vue-Python 客户端

这是基于Electron-Vue-Python框架的客户端模块，集成了现代前端和Python后端技术，为开发强大的跨平台桌面应用提供基础。本README详细说明了当前已集成的技术栈和可以进一步集成的技术栈。

## 已集成技术栈

### 前端技术
| 技术                                          | 版本 | 用途                                 |
| --------------------------------------------- | ---- | ------------------------------------ |
| [Electron](https://www.electronjs.org/)       | 24+  | 跨平台桌面应用框架，提供本地化能力   |
| [Vue 3](https://vuejs.org/)                   | 3.3+ | 响应式UI框架，采用Composition API    |
| [TypeScript](https://www.typescriptlang.org/) | 5.0+ | 类型安全的JavaScript超集             |
| [Ant Design Vue](https://antdv.com/)          | 4.0+ | 企业级UI组件库                       |
| [Vite](https://vitejs.dev/)                   | 4.0+ | 现代前端构建工具，提供快速的开发体验 |
| [Pinia](https://pinia.vuejs.org/)             | 2.1+ | Vue状态管理库，Vue官方推荐           |
| [Vue Router](https://router.vuejs.org/)       | 4.0+ | Vue官方路由管理器                    |
| [ECharts](https://echarts.apache.org/)        | 5.4+ | 强大的数据可视化图表库               |

### 后端技术
| 技术                                                       | 版本   | 用途                                 |
| ---------------------------------------------------------- | ------ | ------------------------------------ |
| [Python](https://www.python.org/)                          | 3.10+  | 后端核心语言，用于数据处理和业务逻辑 |
| [SQLite](https://www.sqlite.org/)                          | 内置   | 轻量级数据库，用于本地数据存储       |
| [python-shell](https://github.com/extrabacon/python-shell) | 最新版 | JavaScript与Python通信的桥梁         |

### 开发与部署工具
| 技术                                            | 版本   | 用途                                 |
| ----------------------------------------------- | ------ | ------------------------------------ |
| [Docker](https://www.docker.com/)               | 最新版 | 容器化应用，提供隔离的开发和运行环境 |
| [npm](https://www.npmjs.com/)                   | 最新版 | JavaScript包管理器                   |
| [electron-builder](https://www.electron.build/) | 最新版 | Electron应用打包工具                 |

## 可扩展/待集成技术栈

### 前端扩展
| 技术                                      | 建议版本 | 潜在用途                             |
| ----------------------------------------- | -------- | ------------------------------------ |
| [TailwindCSS](https://tailwindcss.com/)   | 3.0+     | 实用优先的CSS框架，增强UI开发效率    |
| [Vue I18n](https://vue-i18n.intlify.dev/) | 9.0+     | Vue国际化解决方案，支持多语言        |
| [VueUse](https://vueuse.org/)             | 最新版   | Vue组合式API工具集                   |
| [D3.js](https://d3js.org/)                | 最新版   | 强大的数据可视化库，适合复杂图表需求 |
| [jest](https://jestjs.io/)                | 最新版   | JavaScript测试框架，前端单元测试     |
| [Cypress](https://www.cypress.io/)        | 最新版   | 现代化E2E测试框架                    |

### 后端扩展
| 技术                                                            | 建议版本 | 潜在用途                                   |
| --------------------------------------------------------------- | -------- | ------------------------------------------ |
| [FastAPI](https://fastapi.tiangolo.com/)                        | 最新版   | 高性能Python API框架，可作为微服务         |
| [Django](https://www.djangoproject.com/)                        | 4.2+ LTS | 全功能Web后端框架，适合复杂业务            |
| [Django REST Framework](https://www.django-rest-framework.org/) | 3.14+    | REST API开发框架，配合Django使用           |
| [PostgreSQL](https://www.postgresql.org/)                       | 15+      | 强大的关系型数据库，替代SQLite用于生产环境 |
| [Redis](https://redis.io/)                                      | 7.0+     | 内存数据库，用于缓存和消息队列             |
| [Celery](https://docs.celeryq.dev/)                             | 5.3+     | 分布式任务队列，处理异步任务               |
| [SQLAlchemy](https://www.sqlalchemy.org/)                       | 2.0+     | Python ORM框架，数据库抽象层               |
| [pytest](https://pytest.org/)                                   | 最新版   | Python测试框架                             |

### 云与部署扩展
| 技术                                                  | 建议版本 | 潜在用途                     |
| ----------------------------------------------------- | -------- | ---------------------------- |
| [AWS SDK](https://aws.amazon.com/sdk-for-javascript/) | 最新版   | 与AWS服务集成                |
| [Firebase](https://firebase.google.com/)              | 最新版   | 身份验证、实时数据库等云服务 |
| [Docker Compose](https://docs.docker.com/compose/)    | 最新版   | 多容器Docker应用定义和运行   |
| [GitHub Actions](https://github.com/features/actions) | 最新版   | CI/CD自动化工作流            |

### 加密货币相关技术
| 技术                                                                                | 建议版本 | 潜在用途                      |
| ----------------------------------------------------------------------------------- | -------- | ----------------------------- |
| [ccxt](https://github.com/ccxt/ccxt)                                                | 最新版   | 加密货币交易所API统一库       |
| [Web3.js](https://web3js.readthedocs.io/)                                           | 最新版   | 以太坊JavaScript API          |
| [ethers.js](https://docs.ethers.io/)                                                | 最新版   | 以太坊钱包实现和工具          |
| [TradingView Lightweight Charts](https://github.com/tradingview/lightweight-charts) | 最新版   | 金融图表库，替代或补充ECharts |

## 集成新技术栈指南

### 前端新技术集成
1. 安装依赖:
   ```bash
   npm install <package-name>
   ```

2. 在项目中配置和使用:
   ```javascript
   // vite.config.js 中添加插件配置
   plugins: [
     vue(),
     // 新插件配置
   ]
   ```

3. 在Vue组件中导入和使用:
   ```javascript
   import { newFeature } from 'new-package';
   ```

### 后端新技术集成
1. 更新Python依赖:
   ```bash
   pip install <package-name>
   echo "<package-name>=<version>" >> requirements.txt
   ```

2. 在Python代码中导入和使用:
   ```python
   # client/src/python/main.py
   import new_package
   
   # 使用新包的功能
   ```

3. 如需通过Electron调用，添加适当的接口:
   ```python
   # 添加新功能接口
   def new_function(params):
       # 实现逻辑
       return results
   ```

### 数据库扩展
如需将SQLite替换为PostgreSQL:

1. 安装必要的Python包:
   ```bash
   pip install psycopg2-binary SQLAlchemy
   ```

2. 更新数据库配置:
   ```python
   # 从SQLite
   # engine = create_engine('sqlite:///data/app.db')
   
   # 到PostgreSQL
   engine = create_engine('postgresql://user:password@localhost:5432/dbname')
   ```

## 开发规范

为保持代码质量和一致性，请遵循以下规范:

1. **Vue组件**: 使用组合式API，`.vue`文件采用以下结构:
   ```vue
   <template>
     <!-- 模板代码 -->
   </template>
   
   <script lang="ts" setup>
   // 导入和逻辑
   </script>
   
   <style scoped>
   /* CSS样式 */
   </style>
   ```

2. **Python代码**: 遵循PEP 8规范，使用类型注解
   ```python
   def function_name(param1: str, param2: int) -> bool:
       """函数文档说明"""
       # 实现
       return result
   ```

3. **API接口设计**: 使用RESTful风格，遵循以下模式:
   ```
   GET /resource         # 获取资源列表
   GET /resource/:id     # 获取单个资源
   POST /resource        # 创建新资源
   PUT /resource/:id     # 更新资源
   DELETE /resource/:id  # 删除资源
   ```

## 性能优化建议

集成新技术时，请考虑以下性能优化建议:

1. **懒加载路由**:
   ```javascript
   const routes = [
     {
       path: '/feature',
       component: () => import('./views/Feature.vue')
     }
   ]
   ```

2. **组件按需导入**:
   ```javascript
   // 全部导入
   // import { Button, Select, Table } from 'ant-design-vue'
   
   // 按需导入
   import Button from 'ant-design-vue/lib/button'
   import 'ant-design-vue/lib/button/style/css'
   ```

3. **Python多线程处理**:
   ```python
   import threading
   
   def heavy_task():
       # 耗时操作
   
   thread = threading.Thread(target=heavy_task)
   thread.start()
   ```

## 版本兼容性

添加新技术栈时，请检查版本兼容性:

- 所有Vue相关的库应当兼容Vue 3
- Python包应兼容Python 3.10+
- 注意Electron兼容的Node.js版本范围 