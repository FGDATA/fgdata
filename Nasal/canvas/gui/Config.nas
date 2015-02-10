var Config = {
  new: func(cfg)
  {
    var m = {
      parents: [Config],
      _cfg: cfg
    };
    if( typeof(m._cfg) != "hash" )
      m._cfg = {};

    return m;
  },
  get: func(key, default = nil)
  {
    var val = me._cfg[key];
    if( val != nil )
      return val;

    return default;
  },
  set: func(key, value)
  {
    me._cfg[key] = value;
    return me;
  }
};
