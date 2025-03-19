# 构建阶段
ARG NODE_IMAGE=node:20-slim
FROM ${NODE_IMAGE} AS builder

# 设置工作目录
WORKDIR /app

# 接收源配置环境变量
ARG NPM_REGISTRY
ARG PIP_INDEX_URL
ARG PIP_TRUSTED_HOST

# 完全移除默认源配置，只使用国内镜像源
RUN rm -rf /etc/apt/sources.list.d/* && \
    rm -f /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 确保apt不会使用官方源
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check

# 安装系统依赖 - 只在构建阶段安装一次
RUN apt-get clean && \
    apt-get update -o Acquire::CompressionTypes::Order::=gz && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libx11-xcb1 \
    libgtk-3-0 \
    python3 \
    python3-pip \
    python3-venv \
    git \
    && rm -rf /var/lib/apt/lists/*

# 创建Python虚拟环境
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 设置环境变量，跳过环境检查
ENV SKIP_ENV_CHECK=true

# 配置npm和pip源（如果提供）
RUN if [ -n "$NPM_REGISTRY" ]; then \
    echo "配置npm源: $NPM_REGISTRY" && \
    npm config set registry $NPM_REGISTRY; \
    fi && \
    if [ -n "$PIP_INDEX_URL" ]; then \
    echo "配置pip源: $PIP_INDEX_URL" && \
    pip config set global.index-url $PIP_INDEX_URL && \
    if [ -n "$PIP_TRUSTED_HOST" ]; then \
    echo "配置pip trusted-host: $PIP_TRUSTED_HOST" && \
    pip config set global.trusted-host $PIP_TRUSTED_HOST; \
    fi; \
    fi

# 先复制package.json、vite配置和scripts目录
COPY client/package.json ./
COPY client/vite.config.js ./
COPY client/index.html ./
COPY client/scripts ./scripts/

# 安装Node.js依赖
# 注意：可通过 ./start.sh update-docker 命令更新源配置
RUN npm install --registry=$NPM_REGISTRY --ignore-scripts

# 复制Python依赖
COPY client/requirements.txt ./
# 注意：可通过 ./start.sh update-docker 命令更新源配置
RUN pip install -i $PIP_INDEX_URL --no-cache-dir -r requirements.txt

# 复制剩余源代码和资源 - 放在依赖安装后，这样源代码变化不会导致重新安装依赖
COPY client/src ./src/

# 确保assets目录被正确复制
COPY client/src/assets ./public/assets/

# 查看依赖情况并验证node_modules中是否有vue-router
RUN ls -la node_modules/ | grep vue-router || echo "vue-router not found"

# 如果没有找到vue-router，则单独安装
RUN if [ ! -d "node_modules/vue-router" ]; then npm install --registry=$NPM_REGISTRY --ignore-scripts vue-router; fi

# 构建前端
RUN npm run build

# 打包阶段 - 重用构建阶段的依赖和环境
FROM builder AS packager

# 设置环境变量
ENV NODE_ENV=production
ENV SKIP_ENV_CHECK=true
ENV NPM_CONFIG_REGISTRY=$NPM_REGISTRY
ENV PIP_INDEX_URL=$PIP_INDEX_URL
ENV PIP_TRUSTED_HOST=$PIP_TRUSTED_HOST

# 不需要重新安装依赖，因为已经从builder阶段继承了所有内容
# 只需安装生产环境特有的依赖（如果有）
RUN npm prune --production

# 打包应用
RUN npm run package

# 运行阶段 - 最小化最终镜像
ARG NODE_IMAGE=node:20-slim
FROM ${NODE_IMAGE}

# 设置工作目录
WORKDIR /app

# 完全移除默认源配置，只使用国内镜像源
RUN rm -rf /etc/apt/sources.list.d/* && \
    rm -f /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 确保apt不会使用官方源
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check

# 安装运行时必需的系统依赖
RUN apt-get clean && \
    apt-get update -o Acquire::CompressionTypes::Order::=gz && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libx11-xcb1 \
    libgtk-3-0 \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 复制打包好的应用 - 只复制必要的文件
COPY --from=packager /app/dist ./dist

# 设置入口点
ENTRYPOINT ["./dist/linux-unpacked/crypto-grid-mvp"] 