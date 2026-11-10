export interface CityPreset {
  name: string;
  pinyin: string;
  abbr: string;
  province: string;
  latitude: number;
  longitude: number;
}

export const CITY_LIST: CityPreset[] = [
  // 直辖市
  { name: '北京', pinyin: 'beijing', abbr: 'bj', province: '北京', latitude: 39.9042, longitude: 116.4074 },
  { name: '上海', pinyin: 'shanghai', abbr: 'sh', province: '上海', latitude: 31.2304, longitude: 121.4737 },
  { name: '天津', pinyin: 'tianjin', abbr: 'tj', province: '天津', latitude: 39.0842, longitude: 117.2009 },
  { name: '重庆', pinyin: 'chongqing', abbr: 'cq', province: '重庆', latitude: 29.5630, longitude: 106.5516 },
  // 河北
  { name: '石家庄', pinyin: 'shijiazhuang', abbr: 'sjz', province: '河北', latitude: 38.0428, longitude: 114.5149 },
  { name: '唐山', pinyin: 'tangshan', abbr: 'ts', province: '河北', latitude: 39.6305, longitude: 118.1802 },
  { name: '保定', pinyin: 'baoding', abbr: 'bd', province: '河北', latitude: 38.8740, longitude: 115.4646 },
  { name: '廊坊', pinyin: 'langfang', abbr: 'lf', province: '河北', latitude: 39.5379, longitude: 116.6839 },
  { name: '秦皇岛', pinyin: 'qinhuangdao', abbr: 'qhd', province: '河北', latitude: 39.9354, longitude: 119.6005 },
  { name: '邯郸', pinyin: 'handan', abbr: 'hd', province: '河北', latitude: 36.6253, longitude: 114.5391 },
  // 山西
  { name: '太原', pinyin: 'taiyuan', abbr: 'ty', province: '山西', latitude: 37.8706, longitude: 112.5489 },
  { name: '大同', pinyin: 'datong', abbr: 'dt', province: '山西', latitude: 40.0903, longitude: 113.3001 },
  { name: '临汾', pinyin: 'linfen', abbr: 'lf', province: '山西', latitude: 36.0880, longitude: 111.5190 },
  // 内蒙古
  { name: '呼和浩特', pinyin: 'huhehaote', abbr: 'hhht', province: '内蒙古', latitude: 40.8424, longitude: 111.7490 },
  { name: '包头', pinyin: 'baotou', abbr: 'bt', province: '内蒙古', latitude: 40.6574, longitude: 109.8403 },
  { name: '鄂尔多斯', pinyin: 'eerduosi', abbr: 'eeds', province: '内蒙古', latitude: 39.6086, longitude: 109.7813 },
  { name: '赤峰', pinyin: 'chifeng', abbr: 'cf', province: '内蒙古', latitude: 42.2586, longitude: 118.8869 },
  // 辽宁
  { name: '沈阳', pinyin: 'shenyang', abbr: 'sy', province: '辽宁', latitude: 41.8057, longitude: 123.4315 },
  { name: '大连', pinyin: 'dalian', abbr: 'dl', province: '辽宁', latitude: 38.9140, longitude: 121.6147 },
  { name: '鞍山', pinyin: 'anshan', abbr: 'as', province: '辽宁', latitude: 41.1086, longitude: 122.9943 },
  { name: '锦州', pinyin: 'jinzhou', abbr: 'jz', province: '辽宁', latitude: 41.0955, longitude: 121.1270 },
  // 吉林
  { name: '长春', pinyin: 'changchun', abbr: 'cc', province: '吉林', latitude: 43.8171, longitude: 125.3235 },
  { name: '吉林', pinyin: 'jilin', abbr: 'jl', province: '吉林', latitude: 43.8378, longitude: 126.5495 },
  { name: '延吉', pinyin: 'yanji', abbr: 'yj', province: '吉林', latitude: 42.8913, longitude: 129.5089 },
  // 黑龙江
  { name: '哈尔滨', pinyin: 'haerbin', abbr: 'heb', province: '黑龙江', latitude: 45.8038, longitude: 126.5350 },
  { name: '大庆', pinyin: 'daqing', abbr: 'dq', province: '黑龙江', latitude: 46.5891, longitude: 125.1036 },
  { name: '齐齐哈尔', pinyin: 'qiqihaer', abbr: 'qqhe', province: '黑龙江', latitude: 47.3543, longitude: 123.9181 },
  { name: '牡丹江', pinyin: 'mudanjiang', abbr: 'mdj', province: '黑龙江', latitude: 44.5514, longitude: 129.6329 },
  // 江苏
  { name: '南京', pinyin: 'nanjing', abbr: 'nj', province: '江苏', latitude: 32.0603, longitude: 118.7969 },
  { name: '苏州', pinyin: 'suzhou', abbr: 'sz', province: '江苏', latitude: 31.2989, longitude: 120.5853 },
  { name: '无锡', pinyin: 'wuxi', abbr: 'wx', province: '江苏', latitude: 31.4901, longitude: 120.3119 },
  { name: '常州', pinyin: 'changzhou', abbr: 'cz', province: '江苏', latitude: 31.8112, longitude: 119.9740 },
  { name: '南通', pinyin: 'nantong', abbr: 'nt', province: '江苏', latitude: 31.9802, longitude: 120.8943 },
  { name: '徐州', pinyin: 'xuzhou', abbr: 'xz', province: '江苏', latitude: 34.2058, longitude: 117.2840 },
  { name: '扬州', pinyin: 'yangzhou', abbr: 'yz', province: '江苏', latitude: 32.3942, longitude: 119.4127 },
  // 浙江
  { name: '杭州', pinyin: 'hangzhou', abbr: 'hz', province: '浙江', latitude: 30.2741, longitude: 120.1551 },
  { name: '宁波', pinyin: 'ningbo', abbr: 'nb', province: '浙江', latitude: 29.8683, longitude: 121.5440 },
  { name: '温州', pinyin: 'wenzhou', abbr: 'wz', province: '浙江', latitude: 27.9938, longitude: 120.6994 },
  { name: '绍兴', pinyin: 'shaoxing', abbr: 'sx', province: '浙江', latitude: 30.0023, longitude: 120.5810 },
  { name: '义乌', pinyin: 'yiwu', abbr: 'yw', province: '浙江', latitude: 29.3069, longitude: 120.0753 },
  { name: '嘉兴', pinyin: 'jiaxing', abbr: 'jx', province: '浙江', latitude: 30.7522, longitude: 120.7500 },
  // 安徽
  { name: '合肥', pinyin: 'hefei', abbr: 'hf', province: '安徽', latitude: 31.8206, longitude: 117.2272 },
  { name: '芜湖', pinyin: 'wuhu', abbr: 'wh', province: '安徽', latitude: 31.3526, longitude: 118.4331 },
  { name: '黄山', pinyin: 'huangshan', abbr: 'hs', province: '安徽', latitude: 29.7147, longitude: 118.3376 },
  { name: '蚌埠', pinyin: 'bengbu', abbr: 'bb', province: '安徽', latitude: 32.9163, longitude: 117.3892 },
  // 福建
  { name: '福州', pinyin: 'fuzhou', abbr: 'fz', province: '福建', latitude: 26.0745, longitude: 119.2965 },
  { name: '厦门', pinyin: 'xiamen', abbr: 'xm', province: '福建', latitude: 24.4798, longitude: 118.0894 },
  { name: '泉州', pinyin: 'quanzhou', abbr: 'qz', province: '福建', latitude: 24.8741, longitude: 118.6757 },
  { name: '漳州', pinyin: 'zhangzhou', abbr: 'zz', province: '福建', latitude: 24.5130, longitude: 117.6471 },
  // 江西
  { name: '南昌', pinyin: 'nanchang', abbr: 'nc', province: '江西', latitude: 28.6820, longitude: 115.8579 },
  { name: '赣州', pinyin: 'ganzhou', abbr: 'gz', province: '江西', latitude: 25.8310, longitude: 114.9349 },
  { name: '九江', pinyin: 'jiujiang', abbr: 'jj', province: '江西', latitude: 29.7051, longitude: 116.0019 },
  { name: '景德镇', pinyin: 'jingdezhen', abbr: 'jdz', province: '江西', latitude: 29.2688, longitude: 117.1784 },
  // 山东
  { name: '济南', pinyin: 'jinan', abbr: 'jn', province: '山东', latitude: 36.6512, longitude: 117.1201 },
  { name: '青岛', pinyin: 'qingdao', abbr: 'qd', province: '山东', latitude: 36.0671, longitude: 120.3826 },
  { name: '烟台', pinyin: 'yantai', abbr: 'yt', province: '山东', latitude: 37.4638, longitude: 121.4479 },
  { name: '潍坊', pinyin: 'weifang', abbr: 'wf', province: '山东', latitude: 36.7069, longitude: 119.1618 },
  { name: '临沂', pinyin: 'linyi', abbr: 'ly', province: '山东', latitude: 35.1047, longitude: 118.3565 },
  { name: '淄博', pinyin: 'zibo', abbr: 'zb', province: '山东', latitude: 36.8135, longitude: 118.0550 },
  // 河南
  { name: '郑州', pinyin: 'zhengzhou', abbr: 'zz', province: '河南', latitude: 34.7466, longitude: 113.6254 },
  { name: '洛阳', pinyin: 'luoyang', abbr: 'ly', province: '河南', latitude: 34.6197, longitude: 112.4540 },
  { name: '开封', pinyin: 'kaifeng', abbr: 'kf', province: '河南', latitude: 34.7971, longitude: 114.3076 },
  { name: '南阳', pinyin: 'nanyang', abbr: 'ny', province: '河南', latitude: 32.9908, longitude: 112.5283 },
  // 湖北
  { name: '武汉', pinyin: 'wuhan', abbr: 'wh', province: '湖北', latitude: 30.5928, longitude: 114.3055 },
  { name: '宜昌', pinyin: 'yichang', abbr: 'yc', province: '湖北', latitude: 30.6919, longitude: 111.2865 },
  { name: '襄阳', pinyin: 'xiangyang', abbr: 'xy', province: '湖北', latitude: 32.0090, longitude: 112.1224 },
  { name: '荆州', pinyin: 'jingzhou', abbr: 'jz', province: '湖北', latitude: 30.3356, longitude: 112.2410 },
  // 湖南
  { name: '长沙', pinyin: 'changsha', abbr: 'cs', province: '湖南', latitude: 28.2282, longitude: 112.9388 },
  { name: '株洲', pinyin: 'zhuzhou', abbr: 'zz', province: '湖南', latitude: 27.8274, longitude: 113.1340 },
  { name: '衡阳', pinyin: 'hengyang', abbr: 'hy', province: '湖南', latitude: 26.8938, longitude: 112.5719 },
  { name: '张家界', pinyin: 'zhangjiajie', abbr: 'zjj', province: '湖南', latitude: 29.1170, longitude: 110.4791 },
  // 广东
  { name: '广州', pinyin: 'guangzhou', abbr: 'gz', province: '广东', latitude: 23.1291, longitude: 113.2644 },
  { name: '深圳', pinyin: 'shenzhen', abbr: 'sz', province: '广东', latitude: 22.5431, longitude: 114.0579 },
  { name: '珠海', pinyin: 'zhuhai', abbr: 'zh', province: '广东', latitude: 22.2707, longitude: 113.5767 },
  { name: '佛山', pinyin: 'foshan', abbr: 'fs', province: '广东', latitude: 23.0219, longitude: 113.1214 },
  { name: '东莞', pinyin: 'dongguan', abbr: 'dg', province: '广东', latitude: 23.0207, longitude: 113.7518 },
  { name: '惠州', pinyin: 'huizhou', abbr: 'hz', province: '广东', latitude: 23.1115, longitude: 114.4155 },
  { name: '中山', pinyin: 'zhongshan', abbr: 'zs', province: '广东', latitude: 22.5176, longitude: 113.3928 },
  { name: '汕头', pinyin: 'shantou', abbr: 'st', province: '广东', latitude: 23.3540, longitude: 116.6818 },
  // 广西
  { name: '南宁', pinyin: 'nanning', abbr: 'nn', province: '广西', latitude: 22.8170, longitude: 108.3665 },
  { name: '桂林', pinyin: 'guilin', abbr: 'gl', province: '广西', latitude: 25.2736, longitude: 110.2900 },
  { name: '柳州', pinyin: 'liuzhou', abbr: 'lz', province: '广西', latitude: 24.3146, longitude: 109.4284 },
  { name: '北海', pinyin: 'beihai', abbr: 'bh', province: '广西', latitude: 21.4811, longitude: 109.1200 },
  // 海南
  { name: '海口', pinyin: 'haikou', abbr: 'hk', province: '海南', latitude: 20.0440, longitude: 110.1999 },
  { name: '三亚', pinyin: 'sanya', abbr: 'sy', province: '海南', latitude: 18.2528, longitude: 109.5119 },
  // 四川
  { name: '成都', pinyin: 'chengdu', abbr: 'cd', province: '四川', latitude: 30.5728, longitude: 104.0668 },
  { name: '绵阳', pinyin: 'mianyang', abbr: 'my', province: '四川', latitude: 31.4675, longitude: 104.6796 },
  { name: '乐山', pinyin: 'leshan', abbr: 'ls', province: '四川', latitude: 29.5521, longitude: 103.7659 },
  { name: '宜宾', pinyin: 'yibin', abbr: 'yb', province: '四川', latitude: 28.7657, longitude: 104.6428 },
  { name: '九寨沟', pinyin: 'jiuzhaigou', abbr: 'jzg', province: '四川', latitude: 33.2600, longitude: 103.9180 },
  // 贵州
  { name: '贵阳', pinyin: 'guiyang', abbr: 'gy', province: '贵州', latitude: 26.6470, longitude: 106.6302 },
  { name: '遵义', pinyin: 'zunyi', abbr: 'zy', province: '贵州', latitude: 27.7256, longitude: 106.9275 },
  { name: '六盘水', pinyin: 'liupanshui', abbr: 'lps', province: '贵州', latitude: 26.5925, longitude: 104.8302 },
  // 云南
  { name: '昆明', pinyin: 'kunming', abbr: 'km', province: '云南', latitude: 25.0389, longitude: 102.7183 },
  { name: '大理', pinyin: 'dali', abbr: 'dl', province: '云南', latitude: 25.6065, longitude: 100.2679 },
  { name: '丽江', pinyin: 'lijiang', abbr: 'lj', province: '云南', latitude: 26.8721, longitude: 100.2299 },
  { name: '西双版纳', pinyin: 'xishuangbanna', abbr: 'xsbn', province: '云南', latitude: 22.0017, longitude: 100.7970 },
  // 西藏
  { name: '拉萨', pinyin: 'lasa', abbr: 'ls', province: '西藏', latitude: 29.6520, longitude: 91.1721 },
  { name: '林芝', pinyin: 'linzhi', abbr: 'lz', province: '西藏', latitude: 29.6480, longitude: 94.3610 },
  { name: '日喀则', pinyin: 'rikaze', abbr: 'rkz', province: '西藏', latitude: 29.2690, longitude: 88.8810 },
  // 陕西
  { name: '西安', pinyin: 'xian', abbr: 'xa', province: '陕西', latitude: 34.3416, longitude: 108.9398 },
  { name: '咸阳', pinyin: 'xianyang', abbr: 'xy', province: '陕西', latitude: 34.3299, longitude: 108.7092 },
  { name: '宝鸡', pinyin: 'baoji', abbr: 'bj', province: '陕西', latitude: 34.3616, longitude: 107.2372 },
  { name: '延安', pinyin: 'yanan', abbr: 'ya', province: '陕西', latitude: 36.5853, longitude: 109.4898 },
  // 甘肃
  { name: '兰州', pinyin: 'lanzhou', abbr: 'lz', province: '甘肃', latitude: 36.0611, longitude: 103.8343 },
  { name: '敦煌', pinyin: 'dunhuang', abbr: 'dh', province: '甘肃', latitude: 40.1421, longitude: 94.6618 },
  { name: '天水', pinyin: 'tianshui', abbr: 'ts', province: '甘肃', latitude: 34.5809, longitude: 105.7249 },
  // 青海
  { name: '西宁', pinyin: 'xining', abbr: 'xn', province: '青海', latitude: 36.6171, longitude: 101.7782 },
  { name: '格尔木', pinyin: 'geermu', abbr: 'gem', province: '青海', latitude: 36.4064, longitude: 94.9034 },
  // 宁夏
  { name: '银川', pinyin: 'yinchuan', abbr: 'yc', province: '宁夏', latitude: 38.4872, longitude: 106.2309 },
  { name: '中卫', pinyin: 'zhongwei', abbr: 'zw', province: '宁夏', latitude: 37.5148, longitude: 105.1896 },
  // 新疆
  { name: '乌鲁木齐', pinyin: 'wulumuqi', abbr: 'wlmq', province: '新疆', latitude: 43.8256, longitude: 87.6168 },
  { name: '喀什', pinyin: 'kashi', abbr: 'ks', province: '新疆', latitude: 39.4704, longitude: 75.9898 },
  { name: '伊宁', pinyin: 'yining', abbr: 'yn', province: '新疆', latitude: 43.9166, longitude: 81.3241 },
  { name: '吐鲁番', pinyin: 'tulufan', abbr: 'tlf', province: '新疆', latitude: 42.9476, longitude: 89.1841 },
  { name: '克拉玛依', pinyin: 'kelamayi', abbr: 'klmy', province: '新疆', latitude: 45.5800, longitude: 84.8893 },
  // 港澳台
  { name: '香港', pinyin: 'xianggang', abbr: 'xg', province: '香港', latitude: 22.3193, longitude: 114.1694 },
  { name: '澳门', pinyin: 'aomen', abbr: 'am', province: '澳门', latitude: 22.1987, longitude: 113.5439 },
  { name: '台北', pinyin: 'taibei', abbr: 'tb', province: '台湾', latitude: 25.0330, longitude: 121.5654 },
  { name: '高雄', pinyin: 'gaoxiong', abbr: 'gx', province: '台湾', latitude: 22.6273, longitude: 120.3014 },
  { name: '台中', pinyin: 'taizhong', abbr: 'tz', province: '台湾', latitude: 24.1477, longitude: 120.6736 }
];

export const POPULAR_CITY_NAMES: string[] = ['北京', '上海', '广州', '深圳', '杭州', '成都', '西安', '武汉'];

export function findCity(name: string): CityPreset | undefined {
  for (let i = 0; i < CITY_LIST.length; i++) {
    if (CITY_LIST[i].name === name) {
      return CITY_LIST[i];
    }
  }
  return undefined;
}

export function popularCities(): CityPreset[] {
  const arr: CityPreset[] = [];
  for (let i = 0; i < POPULAR_CITY_NAMES.length; i++) {
    const city: CityPreset | undefined = findCity(POPULAR_CITY_NAMES[i]);
    if (city !== undefined) {
      arr.push(city);
    }
  }
  return arr;
}

/**
 * 按城市名、全拼、拼音首字母、省份进行模糊检索。
 * 查询为空时返回热门城市。结果按匹配强度降序。
 */
export function searchCities(query: string, limit: number): CityPreset[] {
  const q: string = query.trim().toLowerCase();
  if (q.length === 0) {
    return popularCities();
  }

  const scored: CityPreset[] = [];
  const scores: number[] = [];
  for (let i = 0; i < CITY_LIST.length; i++) {
    const city: CityPreset = CITY_LIST[i];
    const score: number = matchScore(city, q);
    if (score <= 0) {
      continue;
    }
    let pos: number = scored.length;
    for (let j = 0; j < scores.length; j++) {
      if (scores[j] < score) {
        pos = j;
        break;
      }
    }
    scored.splice(pos, 0, city);
    scores.splice(pos, 0, score);
    if (scored.length > limit) {
      scored.pop();
      scores.pop();
    }
  }
  return scored;
}

function matchScore(city: CityPreset, q: string): number {
  const name: string = city.name.toLowerCase();
  const pinyin: string = city.pinyin;
  const abbr: string = city.abbr;
  const province: string = city.province.toLowerCase();

  if (name === q || pinyin === q) {
    return 100;
  }
  if (name.indexOf(q) === 0) {
    return 90;
  }
  if (pinyin.indexOf(q) === 0) {
    return 80;
  }
  if (name.indexOf(q) > 0) {
    return 70;
  }
  if (abbr.indexOf(q) === 0) {
    return 60;
  }
  if (pinyin.indexOf(q) > 0) {
    return 50;
  }
  if (province === q) {
    return 45;
  }
  if (province.indexOf(q) >= 0) {
    return 40;
  }
  return 0;
}
