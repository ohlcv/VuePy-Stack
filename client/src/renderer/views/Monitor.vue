<template>
  <div class="monitor-page">
    <div class="page-header">
      <h1>交易监控</h1>
      <div class="refresh-control">
        <a-switch
          v-model:checked="autoRefresh"
          checked-children="自动刷新"
          un-checked-children="手动刷新"
        />
        <a-select v-model:value="refreshInterval" style="width: 120px" :disabled="!autoRefresh">
          <a-select-option :value="5">5秒</a-select-option>
          <a-select-option :value="10">10秒</a-select-option>
          <a-select-option :value="30">30秒</a-select-option>
          <a-select-option :value="60">1分钟</a-select-option>
        </a-select>
        <a-button type="primary" @click="refreshData" :disabled="loading">
          <reload-outlined :spin="loading" /> 刷新数据
        </a-button>
      </div>
    </div>

    <!-- 数据总览 -->
    <a-row :gutter="16" class="stats-cards">
      <a-col :span="6">
        <a-card>
          <template #title>
            <div class="card-title">
              <fund-outlined /> 运行中策略
            </div>
          </template>
          <div class="stats-value">{{ monitorData.runningCount }}</div>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card>
          <template #title>
            <div class="card-title">
              <transaction-outlined /> 今日交易数
            </div>
          </template>
          <div class="stats-value">{{ monitorData.todayTradesCount }}</div>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card>
          <template #title>
            <div class="card-title">
              <dollar-outlined /> 今日盈亏
            </div>
          </template>
          <div class="stats-value" :class="monitorData.todayProfit >= 0 ? 'profit' : 'loss'">
            {{ monitorData.todayProfit >= 0 ? '+' : '' }}{{ monitorData.todayProfit.toFixed(2) }} USDT
          </div>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card>
          <template #title>
            <div class="card-title">
              <line-chart-outlined /> 总盈亏
            </div>
          </template>
          <div class="stats-value" :class="monitorData.totalProfit >= 0 ? 'profit' : 'loss'">
            {{ monitorData.totalProfit >= 0 ? '+' : '' }}{{ monitorData.totalProfit.toFixed(2) }} USDT
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 交易图表 -->
    <a-card title="交易盈亏趋势" class="chart-card">
      <div id="profit-chart" class="chart-container"></div>
    </a-card>

    <!-- 最近交易记录 -->
    <a-card title="最近交易记录" class="trades-card">
      <a-table
        :columns="tradesColumns"
        :dataSource="tradesList"
        :loading="loading"
        rowKey="id"
        :pagination="{ pageSize: 10 }"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'type'">
            <a-tag :color="record.type === '买入' ? 'green' : 'red'">
              {{ record.type }}
            </a-tag>
          </template>
          <template v-if="column.key === 'profit'">
            <span :class="[record.profit >= 0 ? 'profit' : 'loss']">
              {{ record.profit >= 0 ? '+' : '' }}{{ record.profit.toFixed(2) }} USDT
            </span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted, onUnmounted, watch } from 'vue';
import {
  FundOutlined,
  TransactionOutlined,
  DollarOutlined,
  LineChartOutlined,
  ReloadOutlined
} from '@ant-design/icons-vue';
import * as echarts from 'echarts';
import { useStrategyStore } from '../store/strategy';

export default defineComponent({
  components: {
    FundOutlined,
    TransactionOutlined,
    DollarOutlined,
    LineChartOutlined,
    ReloadOutlined
  },
  setup() {
    const strategyStore = useStrategyStore();
    const loading = ref(false);
    const autoRefresh = ref(true);
    const refreshInterval = ref(30); // 默认30秒
    let refreshTimer = null;
    let chartInstance = null;

    // 监控数据
    const monitorData = ref({
      runningCount: 0,
      todayTradesCount: 0,
      todayProfit: 0,
      totalProfit: 0,
      chartData: []
    });

    // 交易列表
    const tradesList = ref([]);

    // 表格列定义
    const tradesColumns = [
      {
        title: '时间',
        dataIndex: 'time',
        key: 'time'
      },
      {
        title: '策略',
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
        title: '交易额',
        dataIndex: 'total',
        key: 'total'
      },
      {
        title: '盈亏',
        dataIndex: 'profit',
        key: 'profit'
      }
    ];

    // 初始化图表
    const initChart = () => {
      if (chartInstance) {
        chartInstance.dispose();
      }
      
      const chartDom = document.getElementById('profit-chart');
      if (!chartDom) return;
      
      chartInstance = echarts.init(chartDom);
      
      const option = {
        tooltip: {
          trigger: 'axis'
        },
        legend: {
          data: ['盈亏金额', '累计盈亏']
        },
        grid: {
          left: '3%',
          right: '4%',
          bottom: '3%',
          containLabel: true
        },
        xAxis: {
          type: 'category',
          boundaryGap: false,
          data: []
        },
        yAxis: {
          type: 'value'
        },
        series: [
          {
            name: '盈亏金额',
            type: 'bar',
            data: []
          },
          {
            name: '累计盈亏',
            type: 'line',
            data: []
          }
        ]
      };
      
      chartInstance.setOption(option);
    };

    // 更新图表数据
    const updateChart = () => {
      if (!chartInstance) return;
      
      const dates = monitorData.value.chartData.map(item => item.date);
      const profits = monitorData.value.chartData.map(item => item.profit);
      
      // 计算累计盈亏
      const cumulativeProfits = [];
      let cumulative = 0;
      profits.forEach(profit => {
        cumulative += profit;
        cumulativeProfits.push(cumulative);
      });
      
      chartInstance.setOption({
        xAxis: {
          data: dates
        },
        series: [
          {
            data: profits
          },
          {
            data: cumulativeProfits
          }
        ]
      });
    };

    // 获取监控数据
    const fetchMonitorData = async () => {
      loading.value = true;
      try {
        const data = await strategyStore.getMonitorData();
        monitorData.value = data.stats;
        tradesList.value = data.trades;
        updateChart();
      } catch (error) {
        console.error('获取监控数据失败:', error);
      } finally {
        loading.value = false;
      }
    };

    // 刷新数据
    const refreshData = () => {
      fetchMonitorData();
    };

    // 设置自动刷新
    const setupAutoRefresh = () => {
      clearInterval(refreshTimer);
      if (autoRefresh.value) {
        refreshTimer = setInterval(() => {
          refreshData();
        }, refreshInterval.value * 1000);
      }
    };

    // 监听刷新间隔变化
    watch([autoRefresh, refreshInterval], () => {
      setupAutoRefresh();
    });

    onMounted(() => {
      initChart();
      fetchMonitorData();
      setupAutoRefresh();
      
      // 监听窗口大小变化，重绘图表
      window.addEventListener('resize', () => {
        chartInstance?.resize();
      });
    });

    onUnmounted(() => {
      clearInterval(refreshTimer);
      chartInstance?.dispose();
      window.removeEventListener('resize', () => {
        chartInstance?.resize();
      });
    });

    return {
      loading,
      autoRefresh,
      refreshInterval,
      monitorData,
      tradesList,
      tradesColumns,
      refreshData
    };
  }
});
</script>

<style scoped>
.monitor-page {
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

.refresh-control {
  display: flex;
  align-items: center;
  gap: 10px;
}

.stats-cards {
  margin-bottom: 24px;
}

.card-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.stats-value {
  font-size: 24px;
  font-weight: bold;
  text-align: center;
}

.chart-card,
.trades-card {
  margin-bottom: 24px;
}

.chart-container {
  height: 400px;
  width: 100%;
}

.profit {
  color: #52c41a;
}

.loss {
  color: #f5222d;
}
</style> 