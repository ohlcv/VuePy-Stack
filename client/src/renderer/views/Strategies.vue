<template>
  <div class="strategies-page">
    <div class="page-header">
      <h1>策略管理</h1>
      <a-button type="primary" @click="showCreateStrategyModal">
        <plus-outlined /> 创建新策略
      </a-button>
    </div>
    
    <!-- 策略列表 -->
    <a-tabs v-model:activeKey="activeTab">
      <a-tab-pane key="running" tab="运行中">
        <a-table
          :dataSource="runningStrategies"
          :columns="strategiesColumns"
          :loading="loading"
          rowKey="id"
          :pagination="{ pageSize: 10 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'status'">
              <a-tag :color="getStatusColor(record.status)">
                {{ record.status }}
              </a-tag>
            </template>
            <template v-if="column.key === 'profit'">
              <span :class="[record.profit >= 0 ? 'profit' : 'loss']">
                {{ record.profit >= 0 ? '+' : '' }}{{ record.profit }} USDT
              </span>
            </template>
            <template v-if="column.key === 'actions'">
              <a-space size="small">
                <a-button type="link" @click="viewStrategy(record)">
                  查看
                </a-button>
                <a-button type="link" @click="editStrategy(record)">
                  编辑
                </a-button>
                <a-button
                  type="link"
                  danger
                  @click="stopStrategy(record)"
                  v-if="record.status === '运行中'"
                >
                  停止
                </a-button>
                <a-button
                  type="link"
                  @click="startStrategy(record)"
                  v-else-if="record.status === '已停止'"
                >
                  启动
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
      
      <a-tab-pane key="stopped" tab="已停止">
        <a-table
          :dataSource="stoppedStrategies"
          :columns="strategiesColumns"
          :loading="loading" 
          rowKey="id"
          :pagination="{ pageSize: 10 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'status'">
              <a-tag :color="getStatusColor(record.status)">
                {{ record.status }}
              </a-tag>
            </template>
            <template v-if="column.key === 'profit'">
              <span :class="[record.profit >= 0 ? 'profit' : 'loss']">
                {{ record.profit >= 0 ? '+' : '' }}{{ record.profit }} USDT
              </span>
            </template>
            <template v-if="column.key === 'actions'">
              <a-space size="small">
                <a-button type="link" @click="viewStrategy(record)">
                  查看
                </a-button>
                <a-button type="link" @click="editStrategy(record)">
                  编辑
                </a-button>
                <a-button
                  type="link"
                  @click="startStrategy(record)"
                  v-if="record.status === '已停止'"
                >
                  启动
                </a-button>
                <a-button
                  type="link"
                  danger
                  @click="deleteStrategy(record)"
                >
                  删除
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
    </a-tabs>
    
    <!-- 创建策略对话框 -->
    <a-modal
      v-model:visible="createModalVisible"
      title="创建新策略"
      width="700px"
      :footer="null"
    >
      <strategy-form
        @submit="handleStrategyFormSubmit"
        @cancel="createModalVisible = false"
      />
    </a-modal>

    <!-- 查看策略对话框 -->
    <a-modal
      v-model:visible="viewModalVisible"
      title="策略详情"
      width="800px"
      :footer="null"
    >
      <strategy-detail
        v-if="currentStrategy"
        :strategy="currentStrategy"
        @close="viewModalVisible = false"
      />
    </a-modal>

    <!-- 编辑策略对话框 -->
    <a-modal
      v-model:visible="editModalVisible"
      title="编辑策略"
      width="700px"
      :footer="null"
    >
      <strategy-form
        v-if="currentStrategy"
        :strategy="currentStrategy"
        @submit="handleStrategyFormSubmit"
        @cancel="editModalVisible = false"
      />
    </a-modal>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { PlusOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';
import { useStrategyStore } from '../store/strategy';
import StrategyForm from '../components/StrategyForm.vue';
import StrategyDetail from '../components/StrategyDetail.vue';

export default defineComponent({
  components: {
    PlusOutlined,
    StrategyForm,
    StrategyDetail
  },
  setup() {
    const route = useRoute();
    const strategyStore = useStrategyStore();
    
    const loading = ref(false);
    const activeTab = ref('running');
    const strategies = ref([]);
    const currentStrategy = ref(null);
    
    // 模态框状态
    const createModalVisible = ref(false);
    const viewModalVisible = ref(false);
    const editModalVisible = ref(false);
    
    // 过滤策略列表
    const runningStrategies = computed(() => 
      strategies.value.filter(s => s.status === '运行中')
    );
    
    const stoppedStrategies = computed(() => 
      strategies.value.filter(s => s.status === '已停止')
    );
    
    const strategiesColumns = [
      {
        title: 'ID',
        dataIndex: 'id',
        key: 'id'
      },
      {
        title: '策略名称',
        dataIndex: 'name',
        key: 'name'
      },
      {
        title: '交易所',
        dataIndex: 'exchange',
        key: 'exchange'
      },
      {
        title: '交易对',
        dataIndex: 'pair',
        key: 'pair'
      },
      {
        title: '网格类型',
        dataIndex: 'gridType',
        key: 'gridType'
      },
      {
        title: '状态',
        dataIndex: 'status',
        key: 'status'
      },
      {
        title: '运行时间',
        dataIndex: 'runningTime',
        key: 'runningTime'
      },
      {
        title: '盈亏',
        dataIndex: 'profit',
        key: 'profit'
      },
      {
        title: '操作',
        key: 'actions'
      }
    ];
    
    // 加载策略列表
    const loadStrategies = async () => {
      loading.value = true;
      try {
        strategies.value = await strategyStore.getStrategies();
      } catch (error) {
        console.error('加载策略列表失败:', error);
        message.error('加载策略列表失败');
      } finally {
        loading.value = false;
      }
    };
    
    // 监听URL查询参数
    watch(
      () => route.query,
      (query) => {
        if (query.action === 'create') {
          showCreateStrategyModal();
        }
      },
      { immediate: true }
    );
    
    onMounted(() => {
      loadStrategies();
    });
    
    // 状态颜色
    const getStatusColor = (status) => {
      const colors = {
        '运行中': 'green',
        '已停止': 'red',
        '错误': 'red',
        '初始化中': 'blue',
        '暂停': 'orange'
      };
      return colors[status] || 'default';
    };
    
    // 操作函数
    const showCreateStrategyModal = () => {
      currentStrategy.value = null;
      createModalVisible.value = true;
    };
    
    const viewStrategy = (strategy) => {
      currentStrategy.value = strategy;
      viewModalVisible.value = true;
    };
    
    const editStrategy = (strategy) => {
      currentStrategy.value = strategy;
      editModalVisible.value = true;
    };
    
    const startStrategy = async (strategy) => {
      try {
        await strategyStore.startStrategy(strategy.id);
        message.success(`策略 ${strategy.name} 已启动`);
        loadStrategies();
      } catch (error) {
        console.error('启动策略失败:', error);
        message.error('启动策略失败');
      }
    };
    
    const stopStrategy = async (strategy) => {
      try {
        await strategyStore.stopStrategy(strategy.id);
        message.success(`策略 ${strategy.name} 已停止`);
        loadStrategies();
      } catch (error) {
        console.error('停止策略失败:', error);
        message.error('停止策略失败');
      }
    };
    
    const deleteStrategy = async (strategy) => {
      try {
        await strategyStore.deleteStrategy(strategy.id);
        message.success(`策略 ${strategy.name} 已删除`);
        loadStrategies();
      } catch (error) {
        console.error('删除策略失败:', error);
        message.error('删除策略失败');
      }
    };
    
    const handleStrategyFormSubmit = async (formData) => {
      try {
        if (currentStrategy.value) {
          // 编辑模式
          await strategyStore.updateStrategy({
            ...formData,
            id: currentStrategy.value.id
          });
          message.success('策略更新成功');
          editModalVisible.value = false;
        } else {
          // 创建模式
          await strategyStore.createStrategy(formData);
          message.success('策略创建成功');
          createModalVisible.value = false;
        }
        loadStrategies();
      } catch (error) {
        console.error('保存策略失败:', error);
        message.error('保存策略失败');
      }
    };
    
    return {
      loading,
      activeTab,
      strategies,
      runningStrategies,
      stoppedStrategies,
      strategiesColumns,
      currentStrategy,
      createModalVisible,
      viewModalVisible,
      editModalVisible,
      getStatusColor,
      showCreateStrategyModal,
      viewStrategy,
      editStrategy,
      startStrategy,
      stopStrategy,
      deleteStrategy,
      handleStrategyFormSubmit
    };
  }
});
</script>

<style scoped>
.strategies-page {
  width: 100%;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.page-header h1 {
  margin: 0;
}

.profit {
  color: #52c41a;
  font-weight: bold;
}

.loss {
  color: #f5222d;
  font-weight: bold;
}
</style> 