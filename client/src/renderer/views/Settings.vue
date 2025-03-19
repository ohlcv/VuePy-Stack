<template>
  <div class="settings-page">
    <h1>系统设置</h1>
    
    <a-tabs v-model:activeKey="activeTab">
      <!-- 交易所设置 -->
      <a-tab-pane key="exchanges" tab="交易所">
        <div class="tab-content">
          <div class="section-header">
            <h2>交易所API管理</h2>
            <a-button type="primary" @click="showAddExchangeModal">
              <plus-outlined /> 添加交易所
            </a-button>
          </div>
          
          <a-table
            :dataSource="exchanges"
            :columns="exchangeColumns"
            :loading="loading.exchanges"
            rowKey="id"
            :pagination="false"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'status'">
                <a-tag :color="record.status === '连接成功' ? 'green' : 'red'">
                  {{ record.status }}
                </a-tag>
              </template>
              <template v-if="column.key === 'actions'">
                <a-space>
                  <a-button type="link" @click="testExchangeConnection(record)">
                    测试连接
                  </a-button>
                  <a-button type="link" @click="editExchange(record)">
                    编辑
                  </a-button>
                  <a-popconfirm
                    title="确定要删除这个交易所API吗?"
                    @confirm="deleteExchange(record)"
                    okText="确定"
                    cancelText="取消"
                  >
                    <a-button type="link" danger>删除</a-button>
                  </a-popconfirm>
                </a-space>
              </template>
            </template>
          </a-table>
        </div>
      </a-tab-pane>
      
      <!-- 系统设置 -->
      <a-tab-pane key="system" tab="系统">
        <div class="tab-content">
          <a-form
            :model="systemSettings"
            label-col="{ span: 6 }"
            wrapper-col="{ span: 14 }"
          >
            <h2>通用设置</h2>
            <a-form-item label="数据目录">
              <a-input
                v-model:value="systemSettings.dataDir"
                placeholder="数据存储路径"
                addon-after="选择"
              />
            </a-form-item>
            
            <a-form-item label="自动启动">
              <a-switch v-model:checked="systemSettings.autoStart" />
            </a-form-item>
            
            <a-form-item label="开机启动">
              <a-switch v-model:checked="systemSettings.startOnBoot" />
            </a-form-item>
            
            <h2>Docker设置</h2>
            <a-form-item label="Docker主机">
              <a-input
                v-model:value="systemSettings.dockerHost"
                placeholder="Docker API地址，例如 unix:///var/run/docker.sock"
              />
            </a-form-item>
            
            <a-form-item label="Hummingbot镜像">
              <a-select v-model:value="systemSettings.hummingbotImage">
                <a-select-option value="hummingbot/hummingbot:latest">
                  hummingbot/hummingbot:latest
                </a-select-option>
                <a-select-option value="hummingbot/hummingbot:development">
                  hummingbot/hummingbot:development
                </a-select-option>
              </a-select>
            </a-form-item>
            
            <h2>日志设置</h2>
            <a-form-item label="日志级别">
              <a-select v-model:value="systemSettings.logLevel">
                <a-select-option value="DEBUG">DEBUG</a-select-option>
                <a-select-option value="INFO">INFO</a-select-option>
                <a-select-option value="WARNING">WARNING</a-select-option>
                <a-select-option value="ERROR">ERROR</a-select-option>
              </a-select>
            </a-form-item>
            
            <a-form-item label="日志保留天数">
              <a-input-number
                v-model:value="systemSettings.logRetentionDays"
                :min="1"
                :max="90"
              />
            </a-form-item>
            
            <a-form-item>
              <a-button type="primary" @click="saveSystemSettings">
                保存设置
              </a-button>
              <a-button style="margin-left: 10px" @click="resetSystemSettings">
                重置
              </a-button>
            </a-form-item>
          </a-form>
        </div>
      </a-tab-pane>
      
      <!-- 关于 -->
      <a-tab-pane key="about" tab="关于">
        <div class="tab-content">
          <div class="about-section">
            <img src="/assets/logo.png" alt="CryptoGrid" class="logo" />
            <h2>CryptoGrid</h2>
            <p class="version">版本: {{ appVersion }}</p>
            <p>加密货币网格交易系统</p>
            
            <a-divider />
            
            <div class="system-info">
              <h3>系统信息</h3>
              <p><strong>操作系统:</strong> {{ systemInfo.os }}</p>
              <p><strong>Docker:</strong> {{ systemInfo.docker }}</p>
              <p><strong>Python:</strong> {{ systemInfo.python }}</p>
              <p><strong>Electron:</strong> {{ systemInfo.electron }}</p>
            </div>
            
            <a-divider />
            
            <a-button type="primary" @click="checkForUpdates">
              检查更新
            </a-button>
            
            <a-button style="margin-left: 10px" @click="viewLogs">
              查看日志
            </a-button>
          </div>
        </div>
      </a-tab-pane>
    </a-tabs>
    
    <!-- 添加/编辑交易所对话框 -->
    <a-modal
      v-model:visible="exchangeModalVisible"
      :title="isEditingExchange ? '编辑交易所' : '添加交易所'"
      @ok="handleExchangeFormSubmit"
      @cancel="exchangeModalVisible = false"
      okText="保存"
      cancelText="取消"
    >
      <a-form
        :model="exchangeForm"
        label-col="{ span: 6 }"
        wrapper-col="{ span: 16 }"
      >
        <a-form-item label="交易所名称" required>
          <a-select
            v-model:value="exchangeForm.name"
            placeholder="选择交易所"
            :disabled="isEditingExchange"
          >
            <a-select-option value="binance">Binance</a-select-option>
            <a-select-option value="kucoin">KuCoin</a-select-option>
            <a-select-option value="huobi">Huobi</a-select-option>
            <a-select-option value="okex">OKEx</a-select-option>
            <a-select-option value="gate">Gate.io</a-select-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="API Key" required>
          <a-input
            v-model:value="exchangeForm.apiKey"
            placeholder="输入API Key"
          />
        </a-form-item>
        
        <a-form-item label="Secret Key" required>
          <a-input-password
            v-model:value="exchangeForm.secretKey"
            placeholder="输入Secret Key"
          />
        </a-form-item>
        
        <a-form-item label="额外参数" v-if="exchangeForm.name === 'binance'">
          <a-input
            v-model:value="exchangeForm.extra"
            placeholder="例如: 用于Binance的Passphrase"
          />
        </a-form-item>
        
        <a-form-item label="交易环境">
          <a-radio-group v-model:value="exchangeForm.testnet">
            <a-radio :value="false">主网</a-radio>
            <a-radio :value="true">测试网</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, reactive, onMounted } from 'vue';
import { PlusOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';
import { useStrategyStore } from '../store/strategy';

export default defineComponent({
  components: {
    PlusOutlined
  },
  setup() {
    const strategyStore = useStrategyStore();
    const activeTab = ref('exchanges');
    
    // 加载状态
    const loading = reactive({
      exchanges: false,
      system: false
    });
    
    // 交易所数据
    const exchanges = ref([]);
    const exchangeColumns = [
      {
        title: '交易所',
        dataIndex: 'name',
        key: 'name'
      },
      {
        title: 'API Key',
        dataIndex: 'apiKey',
        key: 'apiKey',
        customRender: ({ text }) => text.slice(0, 4) + '****' + text.slice(-4)
      },
      {
        title: '测试网',
        dataIndex: 'testnet',
        key: 'testnet',
        customRender: ({ text }) => (text ? '是' : '否')
      },
      {
        title: '状态',
        dataIndex: 'status',
        key: 'status'
      },
      {
        title: '操作',
        key: 'actions'
      }
    ];
    
    // 交易所表单
    const exchangeModalVisible = ref(false);
    const isEditingExchange = ref(false);
    const exchangeForm = reactive({
      id: null,
      name: '',
      apiKey: '',
      secretKey: '',
      extra: '',
      testnet: false
    });
    
    // 系统设置
    const systemSettings = reactive({
      dataDir: '/data',
      autoStart: true,
      startOnBoot: false,
      dockerHost: 'unix:///var/run/docker.sock',
      hummingbotImage: 'hummingbot/hummingbot:latest',
      logLevel: 'INFO',
      logRetentionDays: 30
    });
    
    // 系统信息
    const appVersion = ref('1.0.0');
    const systemInfo = reactive({
      os: '',
      docker: '',
      python: '',
      electron: ''
    });
    
    // 加载交易所列表
    const loadExchanges = async () => {
      loading.exchanges = true;
      try {
        exchanges.value = await strategyStore.getExchanges();
      } catch (error) {
        console.error('加载交易所失败:', error);
        message.error('加载交易所失败');
      } finally {
        loading.exchanges = false;
      }
    };
    
    // 加载系统设置
    const loadSystemSettings = async () => {
      loading.system = true;
      try {
        const settings = await strategyStore.getSystemSettings();
        Object.assign(systemSettings, settings);
      } catch (error) {
        console.error('加载系统设置失败:', error);
        message.error('加载系统设置失败');
      } finally {
        loading.system = false;
      }
    };
    
    // 加载系统信息
    const loadSystemInfo = async () => {
      try {
        const info = await strategyStore.getSystemInfo();
        Object.assign(systemInfo, info);
        appVersion.value = info.version || '1.0.0';
      } catch (error) {
        console.error('加载系统信息失败:', error);
      }
    };
    
    // 交易所操作
    const showAddExchangeModal = () => {
      isEditingExchange.value = false;
      Object.assign(exchangeForm, {
        id: null,
        name: '',
        apiKey: '',
        secretKey: '',
        extra: '',
        testnet: false
      });
      exchangeModalVisible.value = true;
    };
    
    const editExchange = (exchange) => {
      isEditingExchange.value = true;
      Object.assign(exchangeForm, {
        id: exchange.id,
        name: exchange.name,
        apiKey: exchange.apiKey,
        secretKey: exchange.secretKey,
        extra: exchange.extra || '',
        testnet: exchange.testnet
      });
      exchangeModalVisible.value = true;
    };
    
    const handleExchangeFormSubmit = async () => {
      try {
        if (isEditingExchange.value) {
          await strategyStore.updateExchange(exchangeForm);
          message.success('交易所更新成功');
        } else {
          await strategyStore.addExchange(exchangeForm);
          message.success('交易所添加成功');
        }
        exchangeModalVisible.value = false;
        loadExchanges();
      } catch (error) {
        console.error('保存交易所失败:', error);
        message.error('保存交易所失败');
      }
    };
    
    const testExchangeConnection = async (exchange) => {
      try {
        const result = await strategyStore.testExchange(exchange.id);
        if (result.success) {
          message.success('交易所连接测试成功');
        } else {
          message.error(`交易所连接测试失败: ${result.message}`);
        }
        loadExchanges();
      } catch (error) {
        console.error('测试交易所失败:', error);
        message.error('测试交易所失败');
      }
    };
    
    const deleteExchange = async (exchange) => {
      try {
        await strategyStore.deleteExchange(exchange.id);
        message.success('交易所删除成功');
        loadExchanges();
      } catch (error) {
        console.error('删除交易所失败:', error);
        message.error('删除交易所失败');
      }
    };
    
    // 系统设置操作
    const saveSystemSettings = async () => {
      try {
        await strategyStore.saveSystemSettings(systemSettings);
        message.success('系统设置保存成功');
      } catch (error) {
        console.error('保存系统设置失败:', error);
        message.error('保存系统设置失败');
      }
    };
    
    const resetSystemSettings = () => {
      loadSystemSettings();
      message.info('系统设置已重置');
    };
    
    // 关于页面操作
    const checkForUpdates = async () => {
      try {
        const updateInfo = await strategyStore.checkForUpdates();
        if (updateInfo.hasUpdate) {
          message.info(`发现新版本: ${updateInfo.version}`);
        } else {
          message.success('当前已是最新版本');
        }
      } catch (error) {
        console.error('检查更新失败:', error);
        message.error('检查更新失败');
      }
    };
    
    const viewLogs = () => {
      strategyStore.openLogsFolder();
    };
    
    onMounted(() => {
      loadExchanges();
      loadSystemSettings();
      loadSystemInfo();
    });
    
    return {
      activeTab,
      loading,
      exchanges,
      exchangeColumns,
      exchangeModalVisible,
      isEditingExchange,
      exchangeForm,
      systemSettings,
      appVersion,
      systemInfo,
      showAddExchangeModal,
      editExchange,
      handleExchangeFormSubmit,
      testExchangeConnection,
      deleteExchange,
      saveSystemSettings,
      resetSystemSettings,
      checkForUpdates,
      viewLogs
    };
  }
});
</script>

<style scoped>
.settings-page {
  width: 100%;
}

.tab-content {
  padding: 20px 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

h1 {
  margin-bottom: 24px;
}

h2 {
  margin-top: 20px;
  margin-bottom: 20px;
}

.about-section {
  text-align: center;
  max-width: 600px;
  margin: 0 auto;
}

.about-section .logo {
  width: 120px;
  height: 120px;
  margin-bottom: 20px;
}

.about-section .version {
  color: #666;
  margin-bottom: 30px;
}

.system-info {
  text-align: left;
  margin: 20px 0;
}

.system-info h3 {
  margin-bottom: 16px;
}
</style> 