<template>
  <a-form
    ref="formRef"
    :model="formData"
    :rules="rules"
    label-col="{ span: 6 }"
    wrapper-col="{ span: 16 }"
  >
    <!-- 基本信息 -->
    <h2>基本信息</h2>
    <a-form-item label="策略名称" name="name" required>
      <a-input v-model:value="formData.name" placeholder="输入策略名称" />
    </a-form-item>

    <a-form-item label="交易所" name="exchange" required>
      <a-select v-model:value="formData.exchange" placeholder="选择交易所" @change="handleExchangeChange">
        <a-select-option v-for="exchange in exchanges" :key="exchange.id" :value="exchange.name">
          {{ exchange.name }}
        </a-select-option>
      </a-select>
    </a-form-item>

    <a-form-item label="交易对" name="pair" required>
      <a-select
        v-model:value="formData.pair"
        :options="tradingPairs"
        placeholder="选择交易对"
        show-search
        :filter-option="filterOption"
      ></a-select>
    </a-form-item>

    <a-form-item label="交易环境">
      <a-radio-group v-model:value="formData.testnet">
        <a-radio :value="false">主网</a-radio>
        <a-radio :value="true">测试网</a-radio>
      </a-radio-group>
    </a-form-item>

    <!-- 网格参数 -->
    <h2>网格参数</h2>
    <a-form-item label="网格类型" name="gridType" required>
      <a-radio-group v-model:value="formData.gridType" button-style="solid">
        <a-radio-button value="arithmetic">等差网格</a-radio-button>
        <a-radio-button value="geometric">等比网格</a-radio-button>
        <a-radio-button value="custom">自定义网格</a-radio-button>
      </a-radio-group>
    </a-form-item>

    <template v-if="formData.gridType !== 'custom'">
      <a-form-item label="上边界价格" name="upperPrice" required>
        <a-input-number
          v-model:value="formData.upperPrice"
          :min="0"
          :precision="6"
          style="width: 100%"
          placeholder="输入上边界价格"
        />
      </a-form-item>

      <a-form-item label="下边界价格" name="lowerPrice" required>
        <a-input-number
          v-model:value="formData.lowerPrice"
          :min="0"
          :precision="6"
          style="width: 100%"
          placeholder="输入下边界价格"
        />
      </a-form-item>

      <a-form-item label="网格数量" name="gridCount" required>
        <a-input-number
          v-model:value="formData.gridCount"
          :min="2"
          :max="50"
          style="width: 100%"
          placeholder="输入网格数量"
        />
      </a-form-item>
    </template>

    <template v-else>
      <a-form-item label="自定义网格" name="customGrids">
        <a-textarea
          v-model:value="formData.customGrids"
          placeholder="每行输入一个价格，例如：
10000
9900
9800
..."
          :rows="6"
        />
      </a-form-item>
    </template>

    <!-- 资金设置 -->
    <h2>资金设置</h2>
    <a-form-item label="单网格投资额" name="amountPerGrid" required>
      <a-input-number
        v-model:value="formData.amountPerGrid"
        :min="0"
        style="width: 100%"
        placeholder="每个网格的投资金额"
      />
    </a-form-item>

    <a-form-item label="初始持仓比例" name="initialPosition" required>
      <a-slider
        v-model:value="formData.initialPosition"
        :min="0"
        :max="100"
        :step="5"
      />
      <div class="slider-value">{{ formData.initialPosition }}%</div>
    </a-form-item>

    <!-- 高级设置 -->
    <a-collapse v-model:activeKey="activeCollapseKey">
      <a-collapse-panel key="advanced" header="高级设置">
        <a-form-item label="反弹百分比" name="reboundPct">
          <a-input-number
            v-model:value="formData.reboundPct"
            :min="0"
            :max="10"
            :step="0.1"
            style="width: 100%"
            placeholder="价格反弹多少百分比后开仓"
          />
        </a-form-item>

        <a-form-item label="回调百分比" name="pullbackPct">
          <a-input-number
            v-model:value="formData.pullbackPct"
            :min="0"
            :max="10"
            :step="0.1"
            style="width: 100%"
            placeholder="价格回调多少百分比后平仓"
          />
        </a-form-item>

        <a-form-item label="订单超时(秒)" name="orderTimeout">
          <a-input-number
            v-model:value="formData.orderTimeout"
            :min="10"
            :max="300"
            style="width: 100%"
            placeholder="订单超时自动取消时间"
          />
        </a-form-item>
        
        <a-form-item label="自动启动">
          <a-switch v-model:checked="formData.autoStart" />
        </a-form-item>
      </a-collapse-panel>
    </a-collapse>

    <!-- 操作按钮 -->
    <div class="form-actions">
      <a-button @click="$emit('cancel')">取消</a-button>
      <a-button type="primary" @click="submitForm" :loading="loading">
        提交
      </a-button>
    </div>
  </a-form>
</template>

<script lang="ts">
import { defineComponent, ref, reactive, computed, onMounted, watch } from 'vue';
import { useStrategyStore } from '../store/strategy';
import { message } from 'ant-design-vue';

export default defineComponent({
  props: {
    strategy: {
      type: Object,
      default: null
    }
  },
  emits: ['submit', 'cancel'],
  setup(props, { emit }) {
    const strategyStore = useStrategyStore();
    const formRef = ref(null);
    const loading = ref(false);
    const exchanges = ref([]);
    const tradingPairs = ref([]);
    const activeCollapseKey = ref(['']);

    // 表单数据
    const formData = reactive({
      name: '',
      exchange: '',
      pair: '',
      testnet: false,
      gridType: 'arithmetic',
      upperPrice: null,
      lowerPrice: null,
      gridCount: 10,
      customGrids: '',
      amountPerGrid: 10,
      initialPosition: 50,
      reboundPct: 0.5,
      pullbackPct: 0.5,
      orderTimeout: 60,
      autoStart: true
    });

    // 表单验证规则
    const rules = {
      name: [{ required: true, message: '请输入策略名称', trigger: 'blur' }],
      exchange: [{ required: true, message: '请选择交易所', trigger: 'change' }],
      pair: [{ required: true, message: '请选择交易对', trigger: 'change' }],
      gridType: [{ required: true, message: '请选择网格类型', trigger: 'change' }],
      upperPrice: [{ required: true, message: '请输入上边界价格', trigger: 'blur' }],
      lowerPrice: [{ required: true, message: '请输入下边界价格', trigger: 'blur' }],
      gridCount: [{ required: true, message: '请输入网格数量', trigger: 'blur' }],
      customGrids: [
        {
          required: true,
          validator: (rule, value) => {
            if (formData.gridType === 'custom' && (!value || value.trim() === '')) {
              return Promise.reject('请输入自定义网格价格');
            }
            return Promise.resolve();
          },
          trigger: 'blur'
        }
      ],
      amountPerGrid: [{ required: true, message: '请输入单网格投资额', trigger: 'blur' }]
    };

    // 加载交易所列表
    const loadExchanges = async () => {
      try {
        exchanges.value = await strategyStore.getExchanges();
      } catch (error) {
        console.error('加载交易所失败:', error);
        message.error('加载交易所失败');
      }
    };

    // 加载交易对
    const handleExchangeChange = async (value) => {
      formData.pair = '';
      tradingPairs.value = [];
      
      if (!value) return;
      
      try {
        const pairs = await strategyStore.getTradingPairs(value, formData.testnet);
        tradingPairs.value = pairs.map(pair => ({
          value: pair,
          label: pair
        }));
      } catch (error) {
        console.error('加载交易对失败:', error);
        message.error('加载交易对失败');
      }
    };

    // 交易对筛选
    const filterOption = (input, option) => {
      return option.value.toLowerCase().indexOf(input.toLowerCase()) >= 0;
    };

    // 提交表单
    const submitForm = async () => {
      if (!formRef.value) return;
      
      try {
        await formRef.value.validate();
        loading.value = true;
        
        // 转换自定义网格格式
        if (formData.gridType === 'custom') {
          const gridPrices = formData.customGrids
            .split('\n')
            .map(line => line.trim())
            .filter(line => line !== '')
            .map(line => parseFloat(line))
            .filter(price => !isNaN(price))
            .sort((a, b) => b - a); // 按降序排列
          
          if (gridPrices.length < 2) {
            message.error('自定义网格至少需要2个价格');
            loading.value = false;
            return;
          }
          
          formData.customGridPrices = gridPrices;
        }
        
        emit('submit', { ...formData });
      } catch (error) {
        console.error('表单验证失败:', error);
      } finally {
        loading.value = false;
      }
    };

    // 如果是编辑模式，初始化表单数据
    watch(
      () => props.strategy,
      (strategy) => {
        if (!strategy) return;
        
        Object.keys(formData).forEach(key => {
          if (strategy[key] !== undefined) {
            formData[key] = strategy[key];
          }
        });
        
        // 处理自定义网格
        if (strategy.gridType === 'custom' && strategy.customGridPrices) {
          formData.customGrids = strategy.customGridPrices.join('\n');
        }
        
        // 如果存在交易所，加载交易对
        if (strategy.exchange) {
          handleExchangeChange(strategy.exchange);
        }
        
        // 展开高级设置
        activeCollapseKey.value = ['advanced'];
      },
      { immediate: true }
    );

    onMounted(() => {
      loadExchanges();
    });

    return {
      formRef,
      formData,
      rules,
      loading,
      exchanges,
      tradingPairs,
      activeCollapseKey,
      handleExchangeChange,
      filterOption,
      submitForm
    };
  }
});
</script>

<style scoped>
h2 {
  margin: 24px 0 16px;
  font-size: 18px;
}

.form-actions {
  margin-top: 24px;
  text-align: right;
}

.form-actions button {
  margin-left: 8px;
}

.slider-value {
  text-align: center;
  margin-top: 8px;
}
</style> 