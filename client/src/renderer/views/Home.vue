<template>
  <div class="home-page">
    <div class="welcome-section">
      <h1>欢迎使用 CryptoGrid</h1>
      <p>加密货币网格交易系统</p>
      
      <a-row :gutter="16" class="status-cards">
        <a-col :span="8">
          <a-card hoverable>
            <template #cover>
              <fund-outlined class="card-icon" />
            </template>
            <a-card-meta title="策略总数">
              <template #description>{{ stats.totalStrategies || 0 }} 个运行中</template>
            </a-card-meta>
          </a-card>
        </a-col>
        
        <a-col :span="8">
          <a-card hoverable>
            <template #cover>
              <transaction-outlined class="card-icon" />
            </template>
            <a-card-meta title="今日交易">
              <template #description>{{ stats.todayTrades || 0 }} 笔</template>
            </a-card-meta>
          </a-card>
        </a-col>
        
        <a-col :span="8">
          <a-card hoverable>
            <template #cover>
              <line-chart-outlined class="card-icon" />
            </template>
            <a-card-meta title="当前盈亏">
              <template #description>
                <span :class="stats.totalProfit >= 0 ? 'profit' : 'loss'">
                  {{ stats.totalProfit >= 0 ? '+' : '' }}{{ stats.totalProfit || 0 }} USDT
                </span>
              </template>
            </a-card-meta>
          </a-card>
        </a-col>
      </a-row>
    </div>
    
    <a-divider />
    
    <div class="quick-actions">
      <h2>快速操作</h2>
      
      <a-row :gutter="16">
        <a-col :span="12">
          <a-card title="创建新策略" :bordered="false">
            <p>快速创建一个新的网格交易策略</p>
            <a-button type="primary" @click="goToCreateStrategy">
              开始创建
            </a-button>
          </a-card>
        </a-col>
        
        <a-col :span="12">
          <a-card title="查看运行中的策略" :bordered="false">
            <p>查看和管理当前运行的交易策略</p>
            <a-button @click="goToStrategies">
              查看策略
            </a-button>
          </a-card>
        </a-col>
      </a-row>
    </div>
    
    <a-divider />
    
    <div class="recent-trades" v-if="recentTrades.length > 0">
      <h2>最近交易</h2>
      <a-table :dataSource="recentTrades" :columns="columns" />
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { FundOutlined, TransactionOutlined, LineChartOutlined } from '@ant-design/icons-vue';
import { useStrategyStore } from '../store/strategy';

export default defineComponent({
  components: {
    FundOutlined,
    TransactionOutlined,
    LineChartOutlined
  },
  setup() {
    const router = useRouter();
    const strategyStore = useStrategyStore();
    
    const stats = ref({
      totalStrategies: 0,
      todayTrades: 0,
      totalProfit: 0
    });
    
    const recentTrades = ref([]);
    
    const columns = [
      {
        title: '时间',
        dataIndex: 'time',
        key: 'time'
      },
      {
        title: '策略名称',
        dataIndex: 'strategyName',
        key: 'strategyName'
      },
      {
        title: '交易对',
        dataIndex: 'pair',
        key: 'pair'
      },
      {
        title: '类型',
        dataIndex: 'type',
        key: 'type'
      },
      {
        title: '价格',
        dataIndex: 'price',
        key: 'price'
      },
      {
        title: '数量',
        dataIndex: 'amount',
        key: 'amount'
      },
      {
        title: '盈亏',
        dataIndex: 'profit',
        key: 'profit'
      }
    ];
    
    // 获取数据
    onMounted(async () => {
      try {
        const dashboardData = await strategyStore.getDashboardData();
        stats.value = dashboardData.stats;
        recentTrades.value = dashboardData.recentTrades;
      } catch (error) {
        console.error('获取首页数据失败:', error);
      }
    });
    
    // 导航函数
    const goToCreateStrategy = () => {
      router.push('/strategies?action=create');
    };
    
    const goToStrategies = () => {
      router.push('/strategies');
    };
    
    return {
      stats,
      recentTrades,
      columns,
      goToCreateStrategy,
      goToStrategies
    };
  }
});
</script>

<style scoped>
.home-page {
  padding: 20px 0;
}

.welcome-section {
  text-align: center;
  margin-bottom: 40px;
}

.welcome-section h1 {
  font-size: 28px;
  margin-bottom: 8px;
}

.welcome-section p {
  font-size: 16px;
  color: #666;
  margin-bottom: 32px;
}

.status-cards {
  margin-top: 24px;
}

.card-icon {
  font-size: 50px;
  margin: 24px 0;
  display: flex;
  justify-content: center;
  color: #1890ff;
}

.profit {
  color: #52c41a;
  font-weight: bold;
}

.loss {
  color: #f5222d;
  font-weight: bold;
}

.quick-actions h2,
.recent-trades h2 {
  margin-bottom: 24px;
}
</style> 