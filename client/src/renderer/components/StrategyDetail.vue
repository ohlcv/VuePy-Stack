<template>
  <div class="strategy-detail">
    <a-tabs v-model:activeKey="activeTab">
      <!-- 基本信息 -->
      <a-tab-pane key="info" tab="基本信息">
        <a-descriptions :column="2" bordered>
          <a-descriptions-item label="策略ID" :span="2">
            {{ strategy.id }}
          </a-descriptions-item>
          <a-descriptions-item label="策略名称" :span="2">
            {{ strategy.name }}
          </a-descriptions-item>
          <a-descriptions-item label="交易所">
            {{ strategy.exchange }}
          </a-descriptions-item>
          <a-descriptions-item label="交易对">
            {{ strategy.pair }}
          </a-descriptions-item>
          <a-descriptions-item label="状态">
            <a-tag :color="getStatusColor(strategy.status)">
              {{ strategy.status }}
            </a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="运行时间">
            {{ strategy.runningTime || '0秒' }}
          </a-descriptions-item>
          <a-descriptions-item label="网格类型">
            {{ getGridTypeName(strategy.gridType) }}
          </a-descriptions-item>
          <a-descriptions-item label="网格数量">
            {{ getGridCount() }}
          </a-descriptions-item>
          <a-descriptions-item label="价格区间" :span="2">
            {{ getPriceRange() }}
          </a-descriptions-item>
          <a-descriptions-item label="创建时间">
            {{ strategy.createdAt }}
          </a-descriptions-item>
          <a-descriptions-item label="最后更新时间">
            {{ strategy.updatedAt }}
          </a-descriptions-item>
        </a-descriptions>
      </a-tab-pane>
      
      <!-- 性能指标 -->
      <a-tab-pane key="performance" tab="性能指标">
        <div class="performance-cards">
          <a-card class="stat-card">
            <template #title>
              <span class="card-title">总盈亏</span>
            </template>
            <div :class="['stat-value', strategy.profit >= 0 ? 'profit' : 'loss']">
              {{ strategy.profit >= 0 ? '+' : '' }}{{ formatNumber(strategy.profit) }} USDT
            </div>
          </a-card>
          
          <a-card class="stat-card">
            <template #title>
              <span class="card-title">总收益率</span>
            </template>
            <div :class="['stat-value', strategy.roi >= 0 ? 'profit' : 'loss']">
              {{ strategy.roi >= 0 ? '+' : '' }}{{ formatNumber(strategy.roi) }}%
            </div>
          </a-card>
          
          <a-card class="stat-card">
            <template #title>
              <span class="card-title">总成交量</span>
            </template>
            <div class="stat-value">
              {{ formatNumber(strategy.totalVolume) }} USDT
            </div>
          </a-card>
          
          <a-card class="stat-card">
            <template #title>
              <span class="card-title">总成交笔数</span>
            </template>
            <div class="stat-value">
              {{ strategy.totalTrades }}
            </div>
          </a-card>
        </div>
        
        <a-divider />
        
        <div class="chart-container">
          <div id="profit-chart" ref="profitChartRef"></div>
        </div>
      </a-tab-pane>
      
      <!-- 持仓信息 -->
      <a-tab-pane key="position" tab="持仓信息">
        <a-descriptions :column="2" bordered>
          <a-descriptions-item label="基础资产" :span="2">
            <div class="asset-info">
              <span>{{ getBaseAsset() }}</span>
              <span>{{ formatNumber(strategy.baseBalance) }}</span>
            </div>
          </a-descriptions-item>
          <a-descriptions-item label="计价资产" :span="2">
            <div class="asset-info">
              <span>{{ getQuoteAsset() }}</span>
              <span>{{ formatNumber(strategy.quoteBalance) }}</span>
            </div>
          </a-descriptions-item>
          <a-descriptions-item label="总投资" :span="2">
            <div class="asset-info">
              <span>USDT</span>
              <span>{{ formatNumber(strategy.investment) }}</span>
            </div>
          </a-descriptions-item>
          <a-descriptions-item label="当前账户价值" :span="2">
            <div class="asset-info">
              <span>USDT</span>
              <span>{{ formatNumber(strategy.currentValue) }}</span>
            </div>
          </a-descriptions-item>
          <a-descriptions-item label="持仓比例" :span="2">
            <a-progress
              :percent="strategy.positionRatio"
              :stroke-color="getPositionColor(strategy.positionRatio)"
              :format="percent => `${percent}%`"
            />
          </a-descriptions-item>
        </a-descriptions>
        
        <a-divider />
        
        <!-- 网格可视化 -->
        <h3>网格可视化</h3>
        <div class="grid-visualization" ref="gridVisualizationRef"></div>
      </a-tab-pane>
      
      <!-- 订单记录 -->
      <a-tab-pane key="orders" tab="订单记录">
        <a-table
          :dataSource="orders"
          :columns="orderColumns"
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
            <template v-if="column.key === 'status'">
              <a-tag :color="getOrderStatusColor(record.status)">
                {{ record.status }}
              </a-tag>
            </template>
            <template v-if="column.key === 'profit'">
              <span :class="record.profit >= 0 ? 'profit' : 'loss'">
                {{ record.profit >= 0 ? '+' : '' }}{{ formatNumber(record.profit) }}
              </span>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
    </a-tabs>
    
    <div class="detail-actions">
      <a-button @click="$emit('close')">关闭</a-button>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted, onUnmounted, watch } from 'vue';
import * as echarts from 'echarts';
import { useStrategyStore } from '../store/strategy';

export default defineComponent({
  props: {
    strategy: {
      type: Object,
      required: true
    }
  },
  emits: ['close'],
  setup(props) {
    const strategyStore = useStrategyStore();
    const activeTab = ref('info');
    const loading = ref(false);
    const orders = ref([]);
    
    // 图表引用
    const profitChartRef = ref(null);
    const gridVisualizationRef = ref(null);
    
    // 图表实例
    let profitChart = null;
    let gridChart = null;
    
    // 订单表格列定义
    const orderColumns = [
      {
        title: '时间',
        dataIndex: 'time',
        key: 'time'
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
        title: '总额',
        dataIndex: 'total',
        key: 'total'
      },
      {
        title: '状态',
        dataIndex: 'status',
        key: 'status'
      },
      {
        title: '盈亏',
        dataIndex: 'profit',
        key: 'profit'
      }
    ];
    
    // 加载订单数据
    const loadOrders = async () => {
      if (!props.strategy || !props.strategy.id) return;
      
      loading.value = true;
      try {
        orders.value = await strategyStore.getStrategyOrders(props.strategy.id);
      } catch (error) {
        console.error('加载订单记录失败:', error);
      } finally {
        loading.value = false;
      }
    };
    
    // 初始化盈亏图表
    const initProfitChart = () => {
      if (profitChartRef.value) {
        profitChart = echarts.init(profitChartRef.value);
        
        const option = {
          title: {
            text: '策略收益曲线',
            left: 'center'
          },
          tooltip: {
            trigger: 'axis'
          },
          xAxis: {
            type: 'category',
            data: props.strategy.profitHistory?.map(item => item.time) || []
          },
          yAxis: {
            type: 'value',
            name: 'USDT'
          },
          series: [
            {
              name: '收益',
              type: 'line',
              data: props.strategy.profitHistory?.map(item => item.profit) || [],
              markPoint: {
                data: [
                  { type: 'max', name: '最大值' },
                  { type: 'min', name: '最小值' }
                ]
              },
              areaStyle: {
                color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                  {
                    offset: 0,
                    color: 'rgba(58, 77, 233, 0.8)'
                  },
                  {
                    offset: 1,
                    color: 'rgba(58, 77, 233, 0.1)'
                  }
                ])
              }
            }
          ]
        };
        
        profitChart.setOption(option);
      }
    };
    
    // 初始化网格可视化
    const initGridChart = () => {
      if (gridVisualizationRef.value) {
        gridChart = echarts.init(gridVisualizationRef.value);
        
        // 根据策略类型生成网格数据
        const gridPrices = getGridPrices();
        const currentPrice = props.strategy.currentPrice || 
          (gridPrices.length > 0 ? gridPrices[Math.floor(gridPrices.length / 2)] : 0);
        
        const option = {
          title: {
            text: '网格价格分布',
            left: 'center'
          },
          tooltip: {
            formatter: '{b}: {c}'
          },
          grid: {
            left: '3%',
            right: '4%',
            bottom: '3%',
            containLabel: true
          },
          xAxis: {
            type: 'value',
            name: '价格',
            scale: true
          },
          yAxis: {
            type: 'category',
            data: gridPrices.map((_, index) => `网格${index + 1}`),
            inverse: true
          },
          series: [
            {
              name: '网格价格',
              type: 'bar',
              data: gridPrices.map(price => ({
                value: price,
                itemStyle: {
                  color: price > currentPrice ? '#52c41a' : '#f5222d'
                }
              })),
              label: {
                show: true,
                position: 'right',
                formatter: '{c}'
              }
            },
            {
              name: '当前价格',
              type: 'line',
              markLine: {
                data: [
                  {
                    xAxis: currentPrice,
                    lineStyle: {
                      color: '#1890ff',
                      type: 'dashed'
                    },
                    label: {
                      formatter: `当前价格: ${currentPrice}`
                    }
                  }
                ]
              }
            }
          ]
        };
        
        gridChart.setOption(option);
      }
    };
    
    // 获取网格价格分布
    const getGridPrices = () => {
      if (!props.strategy) return [];
      
      // 如果是自定义网格，直接返回自定义价格
      if (props.strategy.gridType === 'custom' && props.strategy.customGridPrices) {
        return [...props.strategy.customGridPrices];
      }
      
      // 计算网格价格
      const { gridType, upperPrice, lowerPrice, gridCount } = props.strategy;
      const prices = [];
      
      if (gridType === 'arithmetic') {
        // 等差网格
        const step = (upperPrice - lowerPrice) / (gridCount - 1);
        for (let i = 0; i < gridCount; i++) {
          prices.push(lowerPrice + step * i);
        }
      } else if (gridType === 'geometric') {
        // 等比网格
        const ratio = Math.pow(upperPrice / lowerPrice, 1 / (gridCount - 1));
        for (let i = 0; i < gridCount; i++) {
          prices.push(lowerPrice * Math.pow(ratio, i));
        }
      }
      
      return prices;
    };
    
    // 获取网格类型名称
    const getGridTypeName = (type) => {
      const types = {
        arithmetic: '等差网格',
        geometric: '等比网格',
        custom: '自定义网格'
      };
      return types[type] || type;
    };
    
    // 获取网格数量
    const getGridCount = () => {
      if (!props.strategy) return 0;
      
      if (props.strategy.gridType === 'custom' && props.strategy.customGridPrices) {
        return props.strategy.customGridPrices.length - 1;
      }
      return props.strategy.gridCount || 0;
    };
    
    // 获取价格区间
    const getPriceRange = () => {
      if (!props.strategy) return '';
      
      if (props.strategy.gridType === 'custom' && props.strategy.customGridPrices) {
        const prices = [...props.strategy.customGridPrices].sort((a, b) => a - b);
        return `${prices[0]} - ${prices[prices.length - 1]}`;
      }
      
      return `${props.strategy.lowerPrice} - ${props.strategy.upperPrice}`;
    };
    
    // 获取状态颜色
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
    
    // 获取订单状态颜色
    const getOrderStatusColor = (status) => {
      const colors = {
        '完成': 'green',
        '部分成交': 'blue',
        '未成交': 'orange',
        '已取消': 'red',
        '失败': 'red'
      };
      return colors[status] || 'default';
    };
    
    // 获取持仓比例颜色
    const getPositionColor = (ratio) => {
      if (ratio <= 20) return '#f5222d';
      if (ratio <= 40) return '#fa8c16';
      if (ratio <= 60) return '#faad14';
      if (ratio <= 80) return '#52c41a';
      return '#1890ff';
    };
    
    // 获取基础资产
    const getBaseAsset = () => {
      if (!props.strategy || !props.strategy.pair) return '';
      const parts = props.strategy.pair.split('-');
      return parts[0] || '';
    };
    
    // 获取计价资产
    const getQuoteAsset = () => {
      if (!props.strategy || !props.strategy.pair) return '';
      const parts = props.strategy.pair.split('-');
      return parts[1] || '';
    };
    
    // 格式化数字
    const formatNumber = (num) => {
      if (num === undefined || num === null) return '0';
      return parseFloat(num).toFixed(2);
    };
    
    // 监听标签页切换
    watch(activeTab, (tab) => {
      if (tab === 'orders') {
        loadOrders();
      } else if (tab === 'performance') {
        setTimeout(() => {
          initProfitChart();
        }, 100);
      } else if (tab === 'position') {
        setTimeout(() => {
          initGridChart();
        }, 100);
      }
    });
    
    onMounted(() => {
      setTimeout(() => {
        initProfitChart();
        initGridChart();
      }, 100);
      
      window.addEventListener('resize', handleResize);
      
      // 加载初始数据
      loadOrders();
    });
    
    onUnmounted(() => {
      if (profitChart) {
        profitChart.dispose();
      }
      if (gridChart) {
        gridChart.dispose();
      }
      window.removeEventListener('resize', handleResize);
    });
    
    const handleResize = () => {
      profitChart?.resize();
      gridChart?.resize();
    };
    
    return {
      activeTab,
      loading,
      orders,
      orderColumns,
      profitChartRef,
      gridVisualizationRef,
      getGridTypeName,
      getGridCount,
      getPriceRange,
      getStatusColor,
      getOrderStatusColor,
      getPositionColor,
      getBaseAsset,
      getQuoteAsset,
      formatNumber
    };
  }
});
</script>

<style scoped>
.strategy-detail {
  width: 100%;
}

.performance-cards {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  margin-bottom: 20px;
}

.stat-card {
  flex: 1;
  min-width: 180px;
}

.card-title {
  font-size: 14px;
}

.stat-value {
  font-size: 24px;
  font-weight: bold;
  text-align: center;
}

.profit {
  color: #52c41a;
}

.loss {
  color: #f5222d;
}

.chart-container {
  margin-top: 20px;
}

#profit-chart,
.grid-visualization {
  width: 100%;
  height: 400px;
}

.detail-actions {
  margin-top: 24px;
  text-align: right;
}

.asset-info {
  display: flex;
  justify-content: space-between;
}
</style> 