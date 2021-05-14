// node_modules/svelte/internal/index.mjs
function noop() {
}
function assign(tar, src) {
  for (const k in src)
    tar[k] = src[k];
  return tar;
}
function run(fn) {
  return fn();
}
function blank_object() {
  return Object.create(null);
}
function run_all(fns) {
  fns.forEach(run);
}
function is_function(thing) {
  return typeof thing === "function";
}
function safe_not_equal(a, b) {
  return a != a ? b == b : a !== b || (a && typeof a === "object" || typeof a === "function");
}
function is_empty(obj) {
  return Object.keys(obj).length === 0;
}
function create_slot(definition, ctx, $$scope, fn) {
  if (definition) {
    const slot_ctx = get_slot_context(definition, ctx, $$scope, fn);
    return definition[0](slot_ctx);
  }
}
function get_slot_context(definition, ctx, $$scope, fn) {
  return definition[1] && fn ? assign($$scope.ctx.slice(), definition[1](fn(ctx))) : $$scope.ctx;
}
function get_slot_changes(definition, $$scope, dirty, fn) {
  if (definition[2] && fn) {
    const lets = definition[2](fn(dirty));
    if ($$scope.dirty === void 0) {
      return lets;
    }
    if (typeof lets === "object") {
      const merged = [];
      const len = Math.max($$scope.dirty.length, lets.length);
      for (let i = 0; i < len; i += 1) {
        merged[i] = $$scope.dirty[i] | lets[i];
      }
      return merged;
    }
    return $$scope.dirty | lets;
  }
  return $$scope.dirty;
}
function update_slot(slot, slot_definition, ctx, $$scope, dirty, get_slot_changes_fn, get_slot_context_fn) {
  const slot_changes = get_slot_changes(slot_definition, $$scope, dirty, get_slot_changes_fn);
  if (slot_changes) {
    const slot_context = get_slot_context(slot_definition, ctx, $$scope, get_slot_context_fn);
    slot.p(slot_context, slot_changes);
  }
}
var tasks = new Set();
var is_hydrating = false;
var nodes_to_detach = new Set();
function start_hydrating() {
  is_hydrating = true;
}
function end_hydrating() {
  is_hydrating = false;
  for (const node of nodes_to_detach) {
    node.parentNode.removeChild(node);
  }
  nodes_to_detach.clear();
}
function append(target, node) {
  if (is_hydrating) {
    nodes_to_detach.delete(node);
  }
  if (node.parentNode !== target) {
    target.appendChild(node);
  }
}
function insert(target, node, anchor) {
  if (is_hydrating) {
    nodes_to_detach.delete(node);
  }
  if (node.parentNode !== target || anchor && node.nextSibling !== anchor) {
    target.insertBefore(node, anchor || null);
  }
}
function detach(node) {
  if (is_hydrating) {
    nodes_to_detach.add(node);
  } else if (node.parentNode) {
    node.parentNode.removeChild(node);
  }
}
function destroy_each(iterations, detaching) {
  for (let i = 0; i < iterations.length; i += 1) {
    if (iterations[i])
      iterations[i].d(detaching);
  }
}
function element(name) {
  return document.createElement(name);
}
function text(data) {
  return document.createTextNode(data);
}
function space() {
  return text(" ");
}
function empty() {
  return text("");
}
function listen(node, event, handler, options) {
  node.addEventListener(event, handler, options);
  return () => node.removeEventListener(event, handler, options);
}
function prevent_default(fn) {
  return function(event) {
    event.preventDefault();
    return fn.call(this, event);
  };
}
function attr(node, attribute, value) {
  if (value == null)
    node.removeAttribute(attribute);
  else if (node.getAttribute(attribute) !== value)
    node.setAttribute(attribute, value);
}
function children(element2) {
  return Array.from(element2.childNodes);
}
function set_data(text2, data) {
  data = "" + data;
  if (text2.wholeText !== data)
    text2.data = data;
}
function set_style(node, key, value, important) {
  node.style.setProperty(key, value, important ? "important" : "");
}
var active_docs = new Set();
var current_component;
function set_current_component(component) {
  current_component = component;
}
function get_current_component() {
  if (!current_component)
    throw new Error("Function called outside component initialization");
  return current_component;
}
function afterUpdate(fn) {
  get_current_component().$$.after_update.push(fn);
}
var dirty_components = [];
var binding_callbacks = [];
var render_callbacks = [];
var flush_callbacks = [];
var resolved_promise = Promise.resolve();
var update_scheduled = false;
function schedule_update() {
  if (!update_scheduled) {
    update_scheduled = true;
    resolved_promise.then(flush);
  }
}
function add_render_callback(fn) {
  render_callbacks.push(fn);
}
var flushing = false;
var seen_callbacks = new Set();
function flush() {
  if (flushing)
    return;
  flushing = true;
  do {
    for (let i = 0; i < dirty_components.length; i += 1) {
      const component = dirty_components[i];
      set_current_component(component);
      update(component.$$);
    }
    set_current_component(null);
    dirty_components.length = 0;
    while (binding_callbacks.length)
      binding_callbacks.pop()();
    for (let i = 0; i < render_callbacks.length; i += 1) {
      const callback = render_callbacks[i];
      if (!seen_callbacks.has(callback)) {
        seen_callbacks.add(callback);
        callback();
      }
    }
    render_callbacks.length = 0;
  } while (dirty_components.length);
  while (flush_callbacks.length) {
    flush_callbacks.pop()();
  }
  update_scheduled = false;
  flushing = false;
  seen_callbacks.clear();
}
function update($$) {
  if ($$.fragment !== null) {
    $$.update();
    run_all($$.before_update);
    const dirty = $$.dirty;
    $$.dirty = [-1];
    $$.fragment && $$.fragment.p($$.ctx, dirty);
    $$.after_update.forEach(add_render_callback);
  }
}
var outroing = new Set();
var outros;
function group_outros() {
  outros = {
    r: 0,
    c: [],
    p: outros
  };
}
function check_outros() {
  if (!outros.r) {
    run_all(outros.c);
  }
  outros = outros.p;
}
function transition_in(block, local) {
  if (block && block.i) {
    outroing.delete(block);
    block.i(local);
  }
}
function transition_out(block, local, detach2, callback) {
  if (block && block.o) {
    if (outroing.has(block))
      return;
    outroing.add(block);
    outros.c.push(() => {
      outroing.delete(block);
      if (callback) {
        if (detach2)
          block.d(1);
        callback();
      }
    });
    block.o(local);
  }
}
var globals = typeof window !== "undefined" ? window : typeof globalThis !== "undefined" ? globalThis : global;
var boolean_attributes = new Set([
  "allowfullscreen",
  "allowpaymentrequest",
  "async",
  "autofocus",
  "autoplay",
  "checked",
  "controls",
  "default",
  "defer",
  "disabled",
  "formnovalidate",
  "hidden",
  "ismap",
  "loop",
  "multiple",
  "muted",
  "nomodule",
  "novalidate",
  "open",
  "playsinline",
  "readonly",
  "required",
  "reversed",
  "selected"
]);
function create_component(block) {
  block && block.c();
}
function mount_component(component, target, anchor, customElement) {
  const {fragment, on_mount, on_destroy, after_update} = component.$$;
  fragment && fragment.m(target, anchor);
  if (!customElement) {
    add_render_callback(() => {
      const new_on_destroy = on_mount.map(run).filter(is_function);
      if (on_destroy) {
        on_destroy.push(...new_on_destroy);
      } else {
        run_all(new_on_destroy);
      }
      component.$$.on_mount = [];
    });
  }
  after_update.forEach(add_render_callback);
}
function destroy_component(component, detaching) {
  const $$ = component.$$;
  if ($$.fragment !== null) {
    run_all($$.on_destroy);
    $$.fragment && $$.fragment.d(detaching);
    $$.on_destroy = $$.fragment = null;
    $$.ctx = [];
  }
}
function make_dirty(component, i) {
  if (component.$$.dirty[0] === -1) {
    dirty_components.push(component);
    schedule_update();
    component.$$.dirty.fill(0);
  }
  component.$$.dirty[i / 31 | 0] |= 1 << i % 31;
}
function init(component, options, instance6, create_fragment6, not_equal, props, dirty = [-1]) {
  const parent_component = current_component;
  set_current_component(component);
  const $$ = component.$$ = {
    fragment: null,
    ctx: null,
    props,
    update: noop,
    not_equal,
    bound: blank_object(),
    on_mount: [],
    on_destroy: [],
    on_disconnect: [],
    before_update: [],
    after_update: [],
    context: new Map(parent_component ? parent_component.$$.context : options.context || []),
    callbacks: blank_object(),
    dirty,
    skip_bound: false
  };
  let ready = false;
  $$.ctx = instance6 ? instance6(component, options.props || {}, (i, ret, ...rest) => {
    const value = rest.length ? rest[0] : ret;
    if ($$.ctx && not_equal($$.ctx[i], $$.ctx[i] = value)) {
      if (!$$.skip_bound && $$.bound[i])
        $$.bound[i](value);
      if (ready)
        make_dirty(component, i);
    }
    return ret;
  }) : [];
  $$.update();
  ready = true;
  run_all($$.before_update);
  $$.fragment = create_fragment6 ? create_fragment6($$.ctx) : false;
  if (options.target) {
    if (options.hydrate) {
      start_hydrating();
      const nodes = children(options.target);
      $$.fragment && $$.fragment.l(nodes);
      nodes.forEach(detach);
    } else {
      $$.fragment && $$.fragment.c();
    }
    if (options.intro)
      transition_in(component.$$.fragment);
    mount_component(component, options.target, options.anchor, options.customElement);
    end_hydrating();
    flush();
  }
  set_current_component(parent_component);
}
var SvelteElement;
if (typeof HTMLElement === "function") {
  SvelteElement = class extends HTMLElement {
    constructor() {
      super();
      this.attachShadow({mode: "open"});
    }
    connectedCallback() {
      const {on_mount} = this.$$;
      this.$$.on_disconnect = on_mount.map(run).filter(is_function);
      for (const key in this.$$.slotted) {
        this.appendChild(this.$$.slotted[key]);
      }
    }
    attributeChangedCallback(attr2, _oldValue, newValue) {
      this[attr2] = newValue;
    }
    disconnectedCallback() {
      run_all(this.$$.on_disconnect);
    }
    $destroy() {
      destroy_component(this, 1);
      this.$destroy = noop;
    }
    $on(type, callback) {
      const callbacks = this.$$.callbacks[type] || (this.$$.callbacks[type] = []);
      callbacks.push(callback);
      return () => {
        const index = callbacks.indexOf(callback);
        if (index !== -1)
          callbacks.splice(index, 1);
      };
    }
    $set($$props) {
      if (this.$$set && !is_empty($$props)) {
        this.$$.skip_bound = true;
        this.$$set($$props);
        this.$$.skip_bound = false;
      }
    }
  };
}
var SvelteComponent = class {
  $destroy() {
    destroy_component(this, 1);
    this.$destroy = noop;
  }
  $on(type, callback) {
    const callbacks = this.$$.callbacks[type] || (this.$$.callbacks[type] = []);
    callbacks.push(callback);
    return () => {
      const index = callbacks.indexOf(callback);
      if (index !== -1)
        callbacks.splice(index, 1);
    };
  }
  $set($$props) {
    if (this.$$set && !is_empty($$props)) {
      this.$$.skip_bound = true;
      this.$$set($$props);
      this.$$.skip_bound = false;
    }
  }
};

// conn.js
var Conn = class {
  constructor(url) {
    this.wsURL = url;
  }
  connect() {
    const ws = new WebSocket(this.wsURL);
    this.ws = ws;
    const self = this;
    ws.addEventListener("open", function(event) {
      self.setConnected(true);
    });
    ws.addEventListener("close", function(event) {
      self.setConnected(false);
    });
    ws.addEventListener("message", function(event) {
      const msg = JSON.parse(event.data);
      self.handleMsg(msg.name, msg.value);
    });
  }
  setConnected(c) {
    console.log("setConnected", c);
  }
  setConfig(mpdhost, artistmode) {
    console.log("setConfig", mpdhost, artistmode);
  }
  setMPDConnected(c) {
    console.log("setMPDConnected", c);
  }
  setPlaylist(c) {
    console.log("setPlaylist", c);
  }
  setPlaybackStatus(songid, state, duration2, elapsed) {
    console.log("setPlaybackStatus", songid, state, duration2, elapsed);
  }
  setList(id, l) {
    console.log("setList", id, l);
  }
  setInodes(id, l) {
    console.log("setInodes", id, l);
  }
  setTrack(id, t) {
    console.log("setTrack", id, t);
  }
  handleMsg(msgName, payload) {
    switch (msgName) {
      case "siren/config":
        this.setConfig(payload.mpdhost, payload.artistmode);
        break;
      case "siren/connection":
        this.setMPDConnected(payload);
        break;
      case "siren/playlist":
        this.setPlaylist(payload);
        break;
      case "siren/status":
        this.setPlaybackStatus(payload.songid, payload.state, payload.duration, payload.elapsed);
        break;
      case "siren/list":
        this.setList(payload.id, payload.list);
        break;
      case "siren/inodes":
        this.setInodes(payload.id, payload.inodes);
        break;
      case "siren/track":
        this.setTrack(payload.id, payload.track);
        break;
      default:
        console.log("unhandled message type", msgName, payload);
    }
  }
  sendCmd(name, payload) {
    if (payload === void 0) {
      payload = {};
    }
    this.ws.send(JSON.stringify({name, value: payload}));
  }
};
var conn_default = Conn;

// duration.js
function duration(t) {
  t = t.toFixed(0);
  var sec = (t % 60).toFixed(0);
  var min = Math.floor(t / 60);
  if (sec < 10) {
    return min + ":0" + sec;
  }
  return min + ":" + sec;
}

// panes.js
var idid = 42;
function genid() {
  idid += 1;
  return "id" + idid;
}
var PaneArtists = class {
  constructor(addpane) {
    this.id = genid();
    this.addpane = addpane;
    this.playlist = void 0;
    this.title = "Artists";
    this.items = [];
  }
  sync(conn) {
    conn.sendCmd("list", {what: "artists", id: this.id});
  }
  setItems(ls) {
    for (const l of ls) {
      this.items.push({
        title: l.artist,
        selected: false,
        onclick: () => {
          this.playlist = l.artist;
          this.addpane(this.nextPane(l.artist), this.id);
          for (var c of this.items) {
            c.selected = c.title == l.artist;
          }
        }
      });
    }
  }
  nextPane(artist) {
    return new PaneAlbums(this.addpane, artist);
  }
  addtoplaylist(conn) {
    conn.sendCmd("findadd", {artist: this.playlist});
  }
};
var PaneAlbums = class {
  constructor(addpane, artist) {
    this.id = genid();
    this.addpane = addpane;
    this.artist = artist;
    this.title = artist;
    this.items = [];
  }
  sync(conn) {
    conn.sendCmd("list", {
      what: "artistalbums",
      id: this.id,
      artist: this.artist
    });
  }
  setItems(ls) {
    for (const l of ls) {
      this.items.push({
        title: l.album,
        onclick: () => {
          this.playlist = l.album;
          this.addpane(this.nextPane(l.artist, l.album), this.id);
          for (var c of this.items) {
            c.selected = c.title == l.album;
          }
        }
      });
    }
  }
  nextPane(artist, album) {
    return new PaneTracks(this.addpane, artist, album);
  }
  addtoplaylist(conn) {
    conn.sendCmd("findadd", {artist: this.artist, album: this.playlist});
  }
};
var PaneTracks = class {
  constructor(addpane, artist, album) {
    this.id = genid();
    this.addpane = addpane;
    this.artist = artist;
    this.album = album;
    this.title = album;
    this.items = [];
  }
  sync(conn) {
    conn.sendCmd("list", {
      what: "araltracks",
      id: this.id,
      artist: this.artist,
      album: this.album
    });
  }
  setItems(ls) {
    for (const l of ls) {
      this.items.push({
        title: l.track.title,
        onclick: () => {
          this.playlist = l.track.title, this.addpane(this.nextPane(l.track.id), this.id);
          for (var c of this.items) {
            c.selected = c.title == l.track.title;
          }
        }
      });
    }
  }
  nextPane(trackid) {
    return new PaneTrack(trackid);
  }
  addtoplaylist(conn) {
    conn.sendCmd("findadd", {
      artist: this.artist,
      album: this.album,
      track: this.playlist
    });
  }
};
function esc(t) {
  return new Option(t).innerHTML;
}
var PaneTrack = class {
  constructor(trackid) {
    this.id = genid();
    this.trackid = trackid;
    this.html = "loading...";
    this.endpane = true;
  }
  sync(conn) {
    conn.sendCmd("track", {
      file: this.trackid,
      id: this.id
    });
  }
  setTrack(track) {
    this.html = esc(track.title) + "<br />artist: " + esc(track.artist) + "<br />album artist: " + esc(track.albumartist) + "<br />album: " + esc(track.album) + "<br />track: " + esc(track.track) + "<br />duration: " + duration(track.duration) + "<br />";
  }
  play(conn) {
    conn.sendCmd("clear");
    conn.sendCmd("add", {id: this.trackid});
    conn.sendCmd("play");
  }
};
var PaneFiles = class {
  constructor(addpane, fileid) {
    this.id = genid();
    this.addpane = addpane;
    this.fileid = fileid;
    this.playlist = void 0;
    this.title = fileid;
    this.items = [];
  }
  sync(conn) {
    conn.sendCmd("loaddir", {file: this.fileid, id: this.id});
  }
  setInodes(elems) {
    for (const l of elems) {
      if (l.file != null) {
        this.items.push({
          title: l.file.title,
          id: l.file.id,
          selected: false,
          onclick: () => {
            this.playlist = l.file.id;
            const next = new PaneTrack(l.file.id);
            this.addpane(next, this.id);
            for (var c of this.items) {
              c.selected = c.id == l.file.id;
            }
          }
        });
      } else {
        this.items.push({
          title: l.dir.title,
          id: l.dir.id,
          selected: false,
          onclick: () => {
            this.playlist = l.dir.id;
            const next = new PaneFiles(this.addpane, l.dir.id);
            this.addpane(next, this.id);
            for (var c of this.items) {
              c.selected = c.id == l.dir.id;
            }
          }
        });
      }
    }
  }
  addtoplaylist(conn) {
    conn.sendCmd("add", {id: this.playlist});
  }
};

// playlist.svelte
function get_each_context(ctx, list, i) {
  const child_ctx = ctx.slice();
  child_ctx[13] = list[i];
  return child_ctx;
}
function get_each_context_1(ctx, list, i) {
  const child_ctx = ctx.slice();
  child_ctx[16] = list[i];
  return child_ctx;
}
function create_each_block_1(ctx) {
  let div5;
  let div0;
  let t0_value = ctx[16].track.track + "";
  let t0;
  let t1;
  let div1;
  let t2_value = ctx[16].track.title + "";
  let t2;
  let t3;
  let div2;
  let t4_value = ctx[16].track.artist + "";
  let t4;
  let t5;
  let div3;
  let t6_value = ctx[16].track.album + "";
  let t6;
  let t7;
  let div4;
  let t8_value = duration(ctx[16].track.duration) + "";
  let t8;
  let t9;
  let div5_class_value;
  let mounted;
  let dispose;
  function click_handler_1() {
    return ctx[6](ctx[16]);
  }
  return {
    c() {
      div5 = element("div");
      div0 = element("div");
      t0 = text(t0_value);
      t1 = space();
      div1 = element("div");
      t2 = text(t2_value);
      t3 = space();
      div2 = element("div");
      t4 = text(t4_value);
      t5 = space();
      div3 = element("div");
      t6 = text(t6_value);
      t7 = space();
      div4 = element("div");
      t8 = text(t8_value);
      t9 = space();
      attr(div0, "class", "track");
      attr(div1, "class", "title");
      attr(div2, "class", "artist");
      attr(div3, "class", "album");
      attr(div4, "class", "dur");
      attr(div5, "class", div5_class_value = "entry " + (ctx[2] === ctx[16].id ? "playing" : ""));
    },
    m(target, anchor) {
      insert(target, div5, anchor);
      append(div5, div0);
      append(div0, t0);
      append(div5, t1);
      append(div5, div1);
      append(div1, t2);
      append(div5, t3);
      append(div5, div2);
      append(div2, t4);
      append(div5, t5);
      append(div5, div3);
      append(div3, t6);
      append(div5, t7);
      append(div5, div4);
      append(div4, t8);
      append(div5, t9);
      if (!mounted) {
        dispose = listen(div5, "click", click_handler_1);
        mounted = true;
      }
    },
    p(new_ctx, dirty) {
      ctx = new_ctx;
      if (dirty & 1 && t0_value !== (t0_value = ctx[16].track.track + ""))
        set_data(t0, t0_value);
      if (dirty & 1 && t2_value !== (t2_value = ctx[16].track.title + ""))
        set_data(t2, t2_value);
      if (dirty & 1 && t4_value !== (t4_value = ctx[16].track.artist + ""))
        set_data(t4, t4_value);
      if (dirty & 1 && t6_value !== (t6_value = ctx[16].track.album + ""))
        set_data(t6, t6_value);
      if (dirty & 1 && t8_value !== (t8_value = duration(ctx[16].track.duration) + ""))
        set_data(t8, t8_value);
      if (dirty & 5 && div5_class_value !== (div5_class_value = "entry " + (ctx[2] === ctx[16].id ? "playing" : ""))) {
        attr(div5, "class", div5_class_value);
      }
    },
    d(detaching) {
      if (detaching)
        detach(div5);
      mounted = false;
      dispose();
    }
  };
}
function create_else_block(ctx) {
  let a;
  let mounted;
  let dispose;
  return {
    c() {
      a = element("a");
      a.innerHTML = `<div style="color: white; width: 42px; display: inline-block"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="currentColor" d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm115.7 272l-176 101c-15.8 8.8-35.7-2.5-35.7-21V152c0-18.4 19.8-29.8 35.7-21l176 107c16.4 9.2 16.4 32.9 0 42z"></path></svg></div>`;
      attr(a, "id", "playplay");
      attr(a, "class", "enabled");
    },
    m(target, anchor) {
      insert(target, a, anchor);
      if (!mounted) {
        dispose = listen(a, "click", ctx[9]);
        mounted = true;
      }
    },
    p: noop,
    d(detaching) {
      if (detaching)
        detach(a);
      mounted = false;
      dispose();
    }
  };
}
function create_if_block_2(ctx) {
  let a;
  let mounted;
  let dispose;
  return {
    c() {
      a = element("a");
      a.innerHTML = `<div style="color: white; width: 42px; display: inline-block"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="currentColor" d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm-16 328c0 8.8-7.2 16-16 16h-48c-8.8 0-16-7.2-16-16V176c0-8.8 7.2-16 16-16h48c8.8 0 16 7.2 16 16v160zm112 0c0 8.8-7.2 16-16 16h-48c-8.8 0-16-7.2-16-16V176c0-8.8 7.2-16 16-16h48c8.8 0 16 7.2 16 16v160z"></path></svg></div>`;
      attr(a, "id", "playpause");
      attr(a, "class", "enabled");
    },
    m(target, anchor) {
      insert(target, a, anchor);
      if (!mounted) {
        dispose = listen(a, "click", ctx[8]);
        mounted = true;
      }
    },
    p: noop,
    d(detaching) {
      if (detaching)
        detach(a);
      mounted = false;
      dispose();
    }
  };
}
function create_if_block(ctx) {
  let each_1_anchor;
  let each_value = ctx[0];
  let each_blocks = [];
  for (let i = 0; i < each_value.length; i += 1) {
    each_blocks[i] = create_each_block(get_each_context(ctx, each_value, i));
  }
  return {
    c() {
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].c();
      }
      each_1_anchor = empty();
    },
    m(target, anchor) {
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].m(target, anchor);
      }
      insert(target, each_1_anchor, anchor);
    },
    p(ctx2, dirty) {
      if (dirty & 29) {
        each_value = ctx2[0];
        let i;
        for (i = 0; i < each_value.length; i += 1) {
          const child_ctx = get_each_context(ctx2, each_value, i);
          if (each_blocks[i]) {
            each_blocks[i].p(child_ctx, dirty);
          } else {
            each_blocks[i] = create_each_block(child_ctx);
            each_blocks[i].c();
            each_blocks[i].m(each_1_anchor.parentNode, each_1_anchor);
          }
        }
        for (; i < each_blocks.length; i += 1) {
          each_blocks[i].d(1);
        }
        each_blocks.length = each_value.length;
      }
    },
    d(detaching) {
      destroy_each(each_blocks, detaching);
      if (detaching)
        detach(each_1_anchor);
    }
  };
}
function create_if_block_1(ctx) {
  let div0;
  let t0_value = ctx[13].track.title + "";
  let t0;
  let t1;
  let div1;
  let t2_value = ctx[13].track.artist + "";
  let t2;
  let t3;
  let div3;
  let input;
  let input_max_value;
  let t4;
  let div2;
  let t5_value = duration(ctx[3]) + "";
  let t5;
  let t6;
  let t7_value = duration(ctx[13].track.duration) + "";
  let t7;
  let t8;
  let mounted;
  let dispose;
  function change_handler(...args) {
    return ctx[12](ctx[13], ...args);
  }
  return {
    c() {
      div0 = element("div");
      t0 = text(t0_value);
      t1 = space();
      div1 = element("div");
      t2 = text(t2_value);
      t3 = space();
      div3 = element("div");
      input = element("input");
      t4 = space();
      div2 = element("div");
      t5 = text(t5_value);
      t6 = text("/");
      t7 = text(t7_value);
      t8 = space();
      attr(div0, "class", "title");
      attr(div1, "class", "artist");
      attr(input, "id", "progress");
      attr(input, "type", "range");
      attr(input, "min", "0");
      attr(input, "max", input_max_value = ctx[13].track.duration);
      input.value = ctx[3];
      attr(div2, "id", "progresstxt");
      attr(div3, "class", "time");
    },
    m(target, anchor) {
      insert(target, div0, anchor);
      append(div0, t0);
      insert(target, t1, anchor);
      insert(target, div1, anchor);
      append(div1, t2);
      insert(target, t3, anchor);
      insert(target, div3, anchor);
      append(div3, input);
      append(div3, t4);
      append(div3, div2);
      append(div2, t5);
      append(div2, t6);
      append(div2, t7);
      append(div3, t8);
      if (!mounted) {
        dispose = listen(input, "change", change_handler);
        mounted = true;
      }
    },
    p(new_ctx, dirty) {
      ctx = new_ctx;
      if (dirty & 1 && t0_value !== (t0_value = ctx[13].track.title + ""))
        set_data(t0, t0_value);
      if (dirty & 1 && t2_value !== (t2_value = ctx[13].track.artist + ""))
        set_data(t2, t2_value);
      if (dirty & 1 && input_max_value !== (input_max_value = ctx[13].track.duration)) {
        attr(input, "max", input_max_value);
      }
      if (dirty & 8) {
        input.value = ctx[3];
      }
      if (dirty & 8 && t5_value !== (t5_value = duration(ctx[3]) + ""))
        set_data(t5, t5_value);
      if (dirty & 1 && t7_value !== (t7_value = duration(ctx[13].track.duration) + ""))
        set_data(t7, t7_value);
    },
    d(detaching) {
      if (detaching)
        detach(div0);
      if (detaching)
        detach(t1);
      if (detaching)
        detach(div1);
      if (detaching)
        detach(t3);
      if (detaching)
        detach(div3);
      mounted = false;
      dispose();
    }
  };
}
function create_each_block(ctx) {
  let if_block_anchor;
  let if_block = ctx[13].id === ctx[2] && create_if_block_1(ctx);
  return {
    c() {
      if (if_block)
        if_block.c();
      if_block_anchor = empty();
    },
    m(target, anchor) {
      if (if_block)
        if_block.m(target, anchor);
      insert(target, if_block_anchor, anchor);
    },
    p(ctx2, dirty) {
      if (ctx2[13].id === ctx2[2]) {
        if (if_block) {
          if_block.p(ctx2, dirty);
        } else {
          if_block = create_if_block_1(ctx2);
          if_block.c();
          if_block.m(if_block_anchor.parentNode, if_block_anchor);
        }
      } else if (if_block) {
        if_block.d(1);
        if_block = null;
      }
    },
    d(detaching) {
      if (if_block)
        if_block.d(detaching);
      if (detaching)
        detach(if_block_anchor);
    }
  };
}
function create_fragment(ctx) {
  let div14;
  let div7;
  let div0;
  let button;
  let t1;
  let div6;
  let t10;
  let div8;
  let t11;
  let div13;
  let div12;
  let a0;
  let div9;
  let a0_class_value;
  let t12;
  let t13;
  let a1;
  let t14;
  let a2;
  let t15;
  let mounted;
  let dispose;
  let each_value_1 = ctx[0];
  let each_blocks = [];
  for (let i = 0; i < each_value_1.length; i += 1) {
    each_blocks[i] = create_each_block_1(get_each_context_1(ctx, each_value_1, i));
  }
  function select_block_type(ctx2, dirty) {
    if (ctx2[1] === "play")
      return create_if_block_2;
    return create_else_block;
  }
  let current_block_type = select_block_type(ctx, -1);
  let if_block0 = current_block_type(ctx);
  let if_block1 = (ctx[1] === "play" || ctx[1] === "pause") && create_if_block(ctx);
  return {
    c() {
      div14 = element("div");
      div7 = element("div");
      div0 = element("div");
      button = element("button");
      button.textContent = "CLEAR PLAYLIST";
      t1 = space();
      div6 = element("div");
      div6.innerHTML = `<div class="track">Track</div> 
			<div class="title">Title</div> 
			<div class="artist">Artist</div> 
			<div class="album">Album</div> 
			<div class="dur"></div>`;
      t10 = space();
      div8 = element("div");
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].c();
      }
      t11 = space();
      div13 = element("div");
      div12 = element("div");
      a0 = element("a");
      div9 = element("div");
      div9.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="currentColor" d="M256 504C119 504 8 393 8 256S119 8 256 8s248 111 248 248-111 248-248 248zM142.1 273l135.5 135.5c9.4 9.4 24.6 9.4 33.9 0l17-17c9.4-9.4 9.4-24.6 0-33.9L226.9 256l101.6-101.6c9.4-9.4 9.4-24.6 0-33.9l-17-17c-9.4-9.4-24.6-9.4-33.9 0L142.1 239c-9.4 9.4-9.4 24.6 0 34z"></path></svg>`;
      t12 = space();
      if_block0.c();
      t13 = space();
      a1 = element("a");
      a1.innerHTML = `<div style="color: white; width: 42px; display: inline-block"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="currentColor" d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm96 328c0 8.8-7.2 16-16 16H176c-8.8 0-16-7.2-16-16V176c0-8.8 7.2-16 16-16h160c8.8 0 16 7.2 16 16v160z"></path></svg></div>`;
      t14 = space();
      a2 = element("a");
      a2.innerHTML = `<div style="color: white; width: 42px; display: inline-block"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="currentColor" d="M256 8c137 0 248 111 248 248S393 504 256 504 8 393 8 256 119 8 256 8zm113.9 231L234.4 103.5c-9.4-9.4-24.6-9.4-33.9 0l-17 17c-9.4 9.4-9.4 24.6 0 33.9L285.1 256 183.5 357.6c-9.4 9.4-9.4 24.6 0 33.9l17 17c9.4 9.4 24.6 9.4 33.9 0L369.9 273c9.4-9.4 9.4-24.6 0-34z"></path></svg></div>`;
      t15 = space();
      if (if_block1)
        if_block1.c();
      attr(div0, "class", "commands");
      attr(div6, "class", "header");
      attr(div7, "class", "playlist");
      attr(div8, "id", "playlist");
      attr(div8, "class", "entries");
      set_style(div9, "color", "white");
      set_style(div9, "width", "42px");
      set_style(div9, "display", "inline-block");
      attr(a0, "id", "playprevious");
      attr(a0, "class", a0_class_value = ctx[1] === "play" ? "enabled" : "");
      attr(a1, "id", "playstop");
      attr(a1, "class", "enabled");
      attr(a2, "id", "playnext");
      attr(a2, "class", "enabled");
      attr(div12, "class", "buttons");
      attr(div13, "class", "player");
      attr(div14, "id", "pageplaylist");
      attr(div14, "class", "playlistwrap");
    },
    m(target, anchor) {
      insert(target, div14, anchor);
      append(div14, div7);
      append(div7, div0);
      append(div0, button);
      append(div7, t1);
      append(div7, div6);
      append(div14, t10);
      append(div14, div8);
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].m(div8, null);
      }
      append(div14, t11);
      append(div14, div13);
      append(div13, div12);
      append(div12, a0);
      append(a0, div9);
      append(div12, t12);
      if_block0.m(div12, null);
      append(div12, t13);
      append(div12, a1);
      append(div12, t14);
      append(div12, a2);
      append(div13, t15);
      if (if_block1)
        if_block1.m(div13, null);
      if (!mounted) {
        dispose = [
          listen(button, "click", ctx[5]),
          listen(a0, "click", ctx[7]),
          listen(a1, "click", ctx[10]),
          listen(a2, "click", ctx[11])
        ];
        mounted = true;
      }
    },
    p(ctx2, [dirty]) {
      if (dirty & 21) {
        each_value_1 = ctx2[0];
        let i;
        for (i = 0; i < each_value_1.length; i += 1) {
          const child_ctx = get_each_context_1(ctx2, each_value_1, i);
          if (each_blocks[i]) {
            each_blocks[i].p(child_ctx, dirty);
          } else {
            each_blocks[i] = create_each_block_1(child_ctx);
            each_blocks[i].c();
            each_blocks[i].m(div8, null);
          }
        }
        for (; i < each_blocks.length; i += 1) {
          each_blocks[i].d(1);
        }
        each_blocks.length = each_value_1.length;
      }
      if (dirty & 2 && a0_class_value !== (a0_class_value = ctx2[1] === "play" ? "enabled" : "")) {
        attr(a0, "class", a0_class_value);
      }
      if (current_block_type === (current_block_type = select_block_type(ctx2, dirty)) && if_block0) {
        if_block0.p(ctx2, dirty);
      } else {
        if_block0.d(1);
        if_block0 = current_block_type(ctx2);
        if (if_block0) {
          if_block0.c();
          if_block0.m(div12, t13);
        }
      }
      if (ctx2[1] === "play" || ctx2[1] === "pause") {
        if (if_block1) {
          if_block1.p(ctx2, dirty);
        } else {
          if_block1 = create_if_block(ctx2);
          if_block1.c();
          if_block1.m(div13, null);
        }
      } else if (if_block1) {
        if_block1.d(1);
        if_block1 = null;
      }
    },
    i: noop,
    o: noop,
    d(detaching) {
      if (detaching)
        detach(div14);
      destroy_each(each_blocks, detaching);
      if_block0.d();
      if (if_block1)
        if_block1.d();
      mounted = false;
      run_all(dispose);
    }
  };
}
function instance($$self, $$props, $$invalidate) {
  let {playlist = []} = $$props;
  let {playback_state = "stop"} = $$props;
  let {playback_songid = "stop"} = $$props;
  let {playback_elapsed = 0} = $$props;
  let {conn = void 0} = $$props;
  const click_handler = () => conn.sendCmd("clear");
  const click_handler_1 = (entry) => {
    conn.sendCmd("playid", {id: entry.id});
  };
  const click_handler_2 = () => conn.sendCmd("previous");
  const click_handler_3 = () => conn.sendCmd("pause");
  const click_handler_42 = () => conn.sendCmd("play");
  const click_handler_5 = () => conn.sendCmd("stop");
  const click_handler_6 = () => conn.sendCmd("next");
  const change_handler = (track, e) => {
    conn.sendCmd("seek", {
      seconds: parseFloat(e.srcElement.value),
      song: track.id
    });
  };
  $$self.$$set = ($$props2) => {
    if ("playlist" in $$props2)
      $$invalidate(0, playlist = $$props2.playlist);
    if ("playback_state" in $$props2)
      $$invalidate(1, playback_state = $$props2.playback_state);
    if ("playback_songid" in $$props2)
      $$invalidate(2, playback_songid = $$props2.playback_songid);
    if ("playback_elapsed" in $$props2)
      $$invalidate(3, playback_elapsed = $$props2.playback_elapsed);
    if ("conn" in $$props2)
      $$invalidate(4, conn = $$props2.conn);
  };
  return [
    playlist,
    playback_state,
    playback_songid,
    playback_elapsed,
    conn,
    click_handler,
    click_handler_1,
    click_handler_2,
    click_handler_3,
    click_handler_42,
    click_handler_5,
    click_handler_6,
    change_handler
  ];
}
var Playlist = class extends SvelteComponent {
  constructor(options) {
    super();
    init(this, options, instance, create_fragment, safe_not_equal, {
      playlist: 0,
      playback_state: 1,
      playback_songid: 2,
      playback_elapsed: 3,
      conn: 4
    });
  }
};
var playlist_default = Playlist;

// pane.svelte
var get_footer_slot_changes = (dirty) => ({});
var get_footer_slot_context = (ctx) => ({});
function get_each_context2(ctx, list, i) {
  const child_ctx = ctx.slice();
  child_ctx[5] = list[i];
  return child_ctx;
}
function create_each_block2(ctx) {
  let div;
  let t_value = ctx[5].title + "";
  let t;
  let div_class_value;
  let div_id_value;
  let mounted;
  let dispose;
  return {
    c() {
      div = element("div");
      t = text(t_value);
      attr(div, "class", div_class_value = ctx[5].selected ? "selected" : "");
      attr(div, "id", div_id_value = ctx[5].id);
    },
    m(target, anchor) {
      insert(target, div, anchor);
      append(div, t);
      if (!mounted) {
        dispose = listen(div, "click", function() {
          if (is_function(ctx[5].onclick))
            ctx[5].onclick.apply(this, arguments);
        });
        mounted = true;
      }
    },
    p(new_ctx, dirty) {
      ctx = new_ctx;
      if (dirty & 4 && t_value !== (t_value = ctx[5].title + ""))
        set_data(t, t_value);
      if (dirty & 4 && div_class_value !== (div_class_value = ctx[5].selected ? "selected" : "")) {
        attr(div, "class", div_class_value);
      }
      if (dirty & 4 && div_id_value !== (div_id_value = ctx[5].id)) {
        attr(div, "id", div_id_value);
      }
    },
    d(detaching) {
      if (detaching)
        detach(div);
      mounted = false;
      dispose();
    }
  };
}
function create_fragment2(ctx) {
  let div3;
  let div0;
  let t0;
  let t1;
  let div1;
  let t2;
  let div2;
  let current;
  let each_value = ctx[2];
  let each_blocks = [];
  for (let i = 0; i < each_value.length; i += 1) {
    each_blocks[i] = create_each_block2(get_each_context2(ctx, each_value, i));
  }
  const footer_slot_template = ctx[4].footer;
  const footer_slot = create_slot(footer_slot_template, ctx, ctx[3], get_footer_slot_context);
  return {
    c() {
      div3 = element("div");
      div0 = element("div");
      t0 = text(ctx[1]);
      t1 = space();
      div1 = element("div");
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].c();
      }
      t2 = space();
      div2 = element("div");
      if (footer_slot)
        footer_slot.c();
      attr(div0, "class", "title");
      attr(div1, "class", "main");
      attr(div2, "class", "footer");
      attr(div3, "class", "pane");
      attr(div3, "id", ctx[0]);
    },
    m(target, anchor) {
      insert(target, div3, anchor);
      append(div3, div0);
      append(div0, t0);
      append(div3, t1);
      append(div3, div1);
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].m(div1, null);
      }
      append(div3, t2);
      append(div3, div2);
      if (footer_slot) {
        footer_slot.m(div2, null);
      }
      current = true;
    },
    p(ctx2, [dirty]) {
      if (!current || dirty & 2)
        set_data(t0, ctx2[1]);
      if (dirty & 4) {
        each_value = ctx2[2];
        let i;
        for (i = 0; i < each_value.length; i += 1) {
          const child_ctx = get_each_context2(ctx2, each_value, i);
          if (each_blocks[i]) {
            each_blocks[i].p(child_ctx, dirty);
          } else {
            each_blocks[i] = create_each_block2(child_ctx);
            each_blocks[i].c();
            each_blocks[i].m(div1, null);
          }
        }
        for (; i < each_blocks.length; i += 1) {
          each_blocks[i].d(1);
        }
        each_blocks.length = each_value.length;
      }
      if (footer_slot) {
        if (footer_slot.p && (!current || dirty & 8)) {
          update_slot(footer_slot, footer_slot_template, ctx2, ctx2[3], dirty, get_footer_slot_changes, get_footer_slot_context);
        }
      }
      if (!current || dirty & 1) {
        attr(div3, "id", ctx2[0]);
      }
    },
    i(local) {
      if (current)
        return;
      transition_in(footer_slot, local);
      current = true;
    },
    o(local) {
      transition_out(footer_slot, local);
      current = false;
    },
    d(detaching) {
      if (detaching)
        detach(div3);
      destroy_each(each_blocks, detaching);
      if (footer_slot)
        footer_slot.d(detaching);
    }
  };
}
function instance2($$self, $$props, $$invalidate) {
  let {$$slots: slots = {}, $$scope} = $$props;
  let {id} = $$props;
  let {title = ""} = $$props;
  let {items = []} = $$props;
  $$self.$$set = ($$props2) => {
    if ("id" in $$props2)
      $$invalidate(0, id = $$props2.id);
    if ("title" in $$props2)
      $$invalidate(1, title = $$props2.title);
    if ("items" in $$props2)
      $$invalidate(2, items = $$props2.items);
    if ("$$scope" in $$props2)
      $$invalidate(3, $$scope = $$props2.$$scope);
  };
  return [id, title, items, $$scope, slots];
}
var Pane = class extends SvelteComponent {
  constructor(options) {
    super();
    init(this, options, instance2, create_fragment2, safe_not_equal, {id: 0, title: 1, items: 2});
  }
};
var pane_default = Pane;

// endpane.svelte
var get_footer_slot_changes2 = (dirty) => ({});
var get_footer_slot_context2 = (ctx) => ({});
function create_fragment3(ctx) {
  let div2;
  let div0;
  let t;
  let div1;
  let current;
  const footer_slot_template = ctx[3].footer;
  const footer_slot = create_slot(footer_slot_template, ctx, ctx[2], get_footer_slot_context2);
  return {
    c() {
      div2 = element("div");
      div0 = element("div");
      t = space();
      div1 = element("div");
      if (footer_slot)
        footer_slot.c();
      attr(div0, "class", "main");
      attr(div1, "class", "footer");
      attr(div2, "class", "endpane");
    },
    m(target, anchor) {
      insert(target, div2, anchor);
      append(div2, div0);
      div0.innerHTML = ctx[0];
      append(div2, t);
      append(div2, div1);
      if (footer_slot) {
        footer_slot.m(div1, null);
      }
      current = true;
    },
    p(ctx2, [dirty]) {
      if (!current || dirty & 1)
        div0.innerHTML = ctx2[0];
      ;
      if (footer_slot) {
        if (footer_slot.p && (!current || dirty & 4)) {
          update_slot(footer_slot, footer_slot_template, ctx2, ctx2[2], dirty, get_footer_slot_changes2, get_footer_slot_context2);
        }
      }
    },
    i(local) {
      if (current)
        return;
      transition_in(footer_slot, local);
      current = true;
    },
    o(local) {
      transition_out(footer_slot, local);
      current = false;
    },
    d(detaching) {
      if (detaching)
        detach(div2);
      if (footer_slot)
        footer_slot.d(detaching);
    }
  };
}
function instance3($$self, $$props, $$invalidate) {
  let {$$slots: slots = {}, $$scope} = $$props;
  const id = "";
  let {content = "loading..."} = $$props;
  $$self.$$set = ($$props2) => {
    if ("content" in $$props2)
      $$invalidate(0, content = $$props2.content);
    if ("$$scope" in $$props2)
      $$invalidate(2, $$scope = $$props2.$$scope);
  };
  return [content, id, $$scope, slots];
}
var Endpane = class extends SvelteComponent {
  constructor(options) {
    super();
    init(this, options, instance3, create_fragment3, safe_not_equal, {id: 1, content: 0});
  }
  get id() {
    return this.$$.ctx[1];
  }
};
var endpane_default = Endpane;

// artists.svelte
function get_each_context3(ctx, list, i) {
  const child_ctx = ctx.slice();
  child_ctx[5] = list[i];
  return child_ctx;
}
function create_else_block2(ctx) {
  let pane;
  let current;
  pane = new pane_default({
    props: {
      id: ctx[5].id,
      title: ctx[5].title,
      onclick: ctx[5].onclick,
      items: ctx[5].items,
      $$slots: {footer: [create_footer_slot_1]},
      $$scope: {ctx}
    }
  });
  return {
    c() {
      create_component(pane.$$.fragment);
    },
    m(target, anchor) {
      mount_component(pane, target, anchor);
      current = true;
    },
    p(ctx2, dirty) {
      const pane_changes = {};
      if (dirty & 1)
        pane_changes.id = ctx2[5].id;
      if (dirty & 1)
        pane_changes.title = ctx2[5].title;
      if (dirty & 1)
        pane_changes.onclick = ctx2[5].onclick;
      if (dirty & 1)
        pane_changes.items = ctx2[5].items;
      if (dirty & 259) {
        pane_changes.$$scope = {dirty, ctx: ctx2};
      }
      pane.$set(pane_changes);
    },
    i(local) {
      if (current)
        return;
      transition_in(pane.$$.fragment, local);
      current = true;
    },
    o(local) {
      transition_out(pane.$$.fragment, local);
      current = false;
    },
    d(detaching) {
      destroy_component(pane, detaching);
    }
  };
}
function create_if_block2(ctx) {
  let endpane;
  let current;
  endpane = new endpane_default({
    props: {
      id: ctx[5].id,
      content: ctx[5].html,
      end: ctx[5].endpane,
      $$slots: {footer: [create_footer_slot]},
      $$scope: {ctx}
    }
  });
  return {
    c() {
      create_component(endpane.$$.fragment);
    },
    m(target, anchor) {
      mount_component(endpane, target, anchor);
      current = true;
    },
    p(ctx2, dirty) {
      const endpane_changes = {};
      if (dirty & 1)
        endpane_changes.id = ctx2[5].id;
      if (dirty & 1)
        endpane_changes.content = ctx2[5].html;
      if (dirty & 1)
        endpane_changes.end = ctx2[5].endpane;
      if (dirty & 259) {
        endpane_changes.$$scope = {dirty, ctx: ctx2};
      }
      endpane.$set(endpane_changes);
    },
    i(local) {
      if (current)
        return;
      transition_in(endpane.$$.fragment, local);
      current = true;
    },
    o(local) {
      transition_out(endpane.$$.fragment, local);
      current = false;
    },
    d(detaching) {
      destroy_component(endpane, detaching);
    }
  };
}
function create_if_block_12(ctx) {
  let button0;
  let t1;
  let button1;
  let mounted;
  let dispose;
  function click_handler_1() {
    return ctx[3](ctx[5]);
  }
  function click_handler_2() {
    return ctx[4](ctx[5]);
  }
  return {
    c() {
      button0 = element("button");
      button0.textContent = "ADD TO PLAYLIST";
      t1 = space();
      button1 = element("button");
      button1.textContent = "PLAY";
      attr(button0, "class", "add");
      attr(button1, "class", "play");
    },
    m(target, anchor) {
      insert(target, button0, anchor);
      insert(target, t1, anchor);
      insert(target, button1, anchor);
      if (!mounted) {
        dispose = [
          listen(button0, "click", click_handler_1),
          listen(button1, "click", click_handler_2)
        ];
        mounted = true;
      }
    },
    p(new_ctx, dirty) {
      ctx = new_ctx;
    },
    d(detaching) {
      if (detaching)
        detach(button0);
      if (detaching)
        detach(t1);
      if (detaching)
        detach(button1);
      mounted = false;
      run_all(dispose);
    }
  };
}
function create_footer_slot_1(ctx) {
  let div;
  let t;
  let if_block = ctx[5].playlist && create_if_block_12(ctx);
  return {
    c() {
      div = element("div");
      if (if_block)
        if_block.c();
      t = space();
      attr(div, "slot", "footer");
    },
    m(target, anchor) {
      insert(target, div, anchor);
      if (if_block)
        if_block.m(div, null);
      append(div, t);
    },
    p(ctx2, dirty) {
      if (ctx2[5].playlist) {
        if (if_block) {
          if_block.p(ctx2, dirty);
        } else {
          if_block = create_if_block_12(ctx2);
          if_block.c();
          if_block.m(div, t);
        }
      } else if (if_block) {
        if_block.d(1);
        if_block = null;
      }
    },
    d(detaching) {
      if (detaching)
        detach(div);
      if (if_block)
        if_block.d();
    }
  };
}
function create_footer_slot(ctx) {
  let div;
  let button;
  let t1;
  let mounted;
  let dispose;
  function click_handler() {
    return ctx[2](ctx[5]);
  }
  return {
    c() {
      div = element("div");
      button = element("button");
      button.textContent = "PLAY";
      t1 = space();
      attr(div, "slot", "footer");
    },
    m(target, anchor) {
      insert(target, div, anchor);
      append(div, button);
      append(div, t1);
      if (!mounted) {
        dispose = listen(button, "click", click_handler);
        mounted = true;
      }
    },
    p(new_ctx, dirty) {
      ctx = new_ctx;
    },
    d(detaching) {
      if (detaching)
        detach(div);
      mounted = false;
      dispose();
    }
  };
}
function create_each_block3(ctx) {
  let current_block_type_index;
  let if_block;
  let if_block_anchor;
  let current;
  const if_block_creators = [create_if_block2, create_else_block2];
  const if_blocks = [];
  function select_block_type(ctx2, dirty) {
    if (ctx2[5].endpane)
      return 0;
    return 1;
  }
  current_block_type_index = select_block_type(ctx, -1);
  if_block = if_blocks[current_block_type_index] = if_block_creators[current_block_type_index](ctx);
  return {
    c() {
      if_block.c();
      if_block_anchor = empty();
    },
    m(target, anchor) {
      if_blocks[current_block_type_index].m(target, anchor);
      insert(target, if_block_anchor, anchor);
      current = true;
    },
    p(ctx2, dirty) {
      let previous_block_index = current_block_type_index;
      current_block_type_index = select_block_type(ctx2, dirty);
      if (current_block_type_index === previous_block_index) {
        if_blocks[current_block_type_index].p(ctx2, dirty);
      } else {
        group_outros();
        transition_out(if_blocks[previous_block_index], 1, 1, () => {
          if_blocks[previous_block_index] = null;
        });
        check_outros();
        if_block = if_blocks[current_block_type_index];
        if (!if_block) {
          if_block = if_blocks[current_block_type_index] = if_block_creators[current_block_type_index](ctx2);
          if_block.c();
        } else {
          if_block.p(ctx2, dirty);
        }
        transition_in(if_block, 1);
        if_block.m(if_block_anchor.parentNode, if_block_anchor);
      }
    },
    i(local) {
      if (current)
        return;
      transition_in(if_block);
      current = true;
    },
    o(local) {
      transition_out(if_block);
      current = false;
    },
    d(detaching) {
      if_blocks[current_block_type_index].d(detaching);
      if (detaching)
        detach(if_block_anchor);
    }
  };
}
function create_fragment4(ctx) {
  let div;
  let current;
  let each_value = ctx[0];
  let each_blocks = [];
  for (let i = 0; i < each_value.length; i += 1) {
    each_blocks[i] = create_each_block3(get_each_context3(ctx, each_value, i));
  }
  const out = (i) => transition_out(each_blocks[i], 1, 1, () => {
    each_blocks[i] = null;
  });
  return {
    c() {
      div = element("div");
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].c();
      }
      attr(div, "class", "mc");
    },
    m(target, anchor) {
      insert(target, div, anchor);
      for (let i = 0; i < each_blocks.length; i += 1) {
        each_blocks[i].m(div, null);
      }
      current = true;
    },
    p(ctx2, [dirty]) {
      if (dirty & 3) {
        each_value = ctx2[0];
        let i;
        for (i = 0; i < each_value.length; i += 1) {
          const child_ctx = get_each_context3(ctx2, each_value, i);
          if (each_blocks[i]) {
            each_blocks[i].p(child_ctx, dirty);
            transition_in(each_blocks[i], 1);
          } else {
            each_blocks[i] = create_each_block3(child_ctx);
            each_blocks[i].c();
            transition_in(each_blocks[i], 1);
            each_blocks[i].m(div, null);
          }
        }
        group_outros();
        for (i = each_value.length; i < each_blocks.length; i += 1) {
          out(i);
        }
        check_outros();
      }
    },
    i(local) {
      if (current)
        return;
      for (let i = 0; i < each_value.length; i += 1) {
        transition_in(each_blocks[i]);
      }
      current = true;
    },
    o(local) {
      each_blocks = each_blocks.filter(Boolean);
      for (let i = 0; i < each_blocks.length; i += 1) {
        transition_out(each_blocks[i]);
      }
      current = false;
    },
    d(detaching) {
      if (detaching)
        detach(div);
      destroy_each(each_blocks, detaching);
    }
  };
}
function instance4($$self, $$props, $$invalidate) {
  let {artists = []} = $$props;
  let {conn = void 0} = $$props;
  const click_handler = (pane) => pane.play(conn);
  const click_handler_1 = (pane) => {
    pane.addtoplaylist(conn);
  };
  const click_handler_2 = (pane) => {
    conn.sendCmd("clear");
    pane.addtoplaylist(conn);
    conn.sendCmd("play");
  };
  $$self.$$set = ($$props2) => {
    if ("artists" in $$props2)
      $$invalidate(0, artists = $$props2.artists);
    if ("conn" in $$props2)
      $$invalidate(1, conn = $$props2.conn);
  };
  return [artists, conn, click_handler, click_handler_1, click_handler_2];
}
var Artists = class extends SvelteComponent {
  constructor(options) {
    super();
    init(this, options, instance4, create_fragment4, safe_not_equal, {artists: 0, conn: 1});
  }
};
var artists_default = Artists;

// app.svelte
function create_else_block_1(ctx) {
  let a;
  let mounted;
  let dispose;
  return {
    c() {
      a = element("a");
      a.textContent = "Offline";
      attr(a, "href", "#reconnect");
      attr(a, "class", "status offline");
      attr(a, "title", "offline. Click to reconnect");
    },
    m(target, anchor) {
      insert(target, a, anchor);
      if (!mounted) {
        dispose = listen(a, "click", prevent_default(ctx[8]));
        mounted = true;
      }
    },
    p: noop,
    d(detaching) {
      if (detaching)
        detach(a);
      mounted = false;
      dispose();
    }
  };
}
function create_if_block_3(ctx) {
  let a;
  let a_title_value;
  let mounted;
  let dispose;
  function select_block_type_1(ctx2, dirty) {
    if (ctx2[0].mpdconnected)
      return create_if_block_4;
    return create_else_block3;
  }
  let current_block_type = select_block_type_1(ctx, -1);
  let if_block = current_block_type(ctx);
  return {
    c() {
      a = element("a");
      if_block.c();
      attr(a, "href", "#reconnect");
      attr(a, "class", "status online");
      attr(a, "title", a_title_value = ctx[0].mpdconnected ? "connected to the Siren daemon, and to MPD {mpd.mpdhost}" : "connected to the Siren daemon, but no connection to MPD {mpd.mpdhost}");
    },
    m(target, anchor) {
      insert(target, a, anchor);
      if_block.m(a, null);
      if (!mounted) {
        dispose = listen(a, "click", prevent_default(click_handler_4));
        mounted = true;
      }
    },
    p(ctx2, dirty) {
      if (current_block_type !== (current_block_type = select_block_type_1(ctx2, dirty))) {
        if_block.d(1);
        if_block = current_block_type(ctx2);
        if (if_block) {
          if_block.c();
          if_block.m(a, null);
        }
      }
      if (dirty & 1 && a_title_value !== (a_title_value = ctx2[0].mpdconnected ? "connected to the Siren daemon, and to MPD {mpd.mpdhost}" : "connected to the Siren daemon, but no connection to MPD {mpd.mpdhost}")) {
        attr(a, "title", a_title_value);
      }
    },
    d(detaching) {
      if (detaching)
        detach(a);
      if_block.d();
      mounted = false;
      dispose();
    }
  };
}
function create_else_block3(ctx) {
  let t;
  return {
    c() {
      t = text("No MPD");
    },
    m(target, anchor) {
      insert(target, t, anchor);
    },
    d(detaching) {
      if (detaching)
        detach(t);
    }
  };
}
function create_if_block_4(ctx) {
  let t;
  return {
    c() {
      t = text("Online");
    },
    m(target, anchor) {
      insert(target, t, anchor);
    },
    d(detaching) {
      if (detaching)
        detach(t);
    }
  };
}
function create_if_block_22(ctx) {
  let artists;
  let current;
  artists = new artists_default({
    props: {
      artists: ctx[0].artistPanes,
      conn: ctx[2]
    }
  });
  return {
    c() {
      create_component(artists.$$.fragment);
    },
    m(target, anchor) {
      mount_component(artists, target, anchor);
      current = true;
    },
    p(ctx2, dirty) {
      const artists_changes = {};
      if (dirty & 1)
        artists_changes.artists = ctx2[0].artistPanes;
      if (dirty & 4)
        artists_changes.conn = ctx2[2];
      artists.$set(artists_changes);
    },
    i(local) {
      if (current)
        return;
      transition_in(artists.$$.fragment, local);
      current = true;
    },
    o(local) {
      transition_out(artists.$$.fragment, local);
      current = false;
    },
    d(detaching) {
      destroy_component(artists, detaching);
    }
  };
}
function create_if_block_13(ctx) {
  let artists;
  let current;
  artists = new artists_default({
    props: {
      artists: ctx[0].filePanes,
      conn: ctx[2]
    }
  });
  return {
    c() {
      create_component(artists.$$.fragment);
    },
    m(target, anchor) {
      mount_component(artists, target, anchor);
      current = true;
    },
    p(ctx2, dirty) {
      const artists_changes = {};
      if (dirty & 1)
        artists_changes.artists = ctx2[0].filePanes;
      if (dirty & 4)
        artists_changes.conn = ctx2[2];
      artists.$set(artists_changes);
    },
    i(local) {
      if (current)
        return;
      transition_in(artists.$$.fragment, local);
      current = true;
    },
    o(local) {
      transition_out(artists.$$.fragment, local);
      current = false;
    },
    d(detaching) {
      destroy_component(artists, detaching);
    }
  };
}
function create_if_block3(ctx) {
  let playlist;
  let current;
  playlist = new playlist_default({
    props: {
      playlist: ctx[0].playlist,
      conn: ctx[2],
      playback_state: ctx[0].playback_state,
      playback_songid: ctx[0].playback_songid,
      playback_elapsed: ctx[0].playback_elapsed
    }
  });
  return {
    c() {
      create_component(playlist.$$.fragment);
    },
    m(target, anchor) {
      mount_component(playlist, target, anchor);
      current = true;
    },
    p(ctx2, dirty) {
      const playlist_changes = {};
      if (dirty & 1)
        playlist_changes.playlist = ctx2[0].playlist;
      if (dirty & 4)
        playlist_changes.conn = ctx2[2];
      if (dirty & 1)
        playlist_changes.playback_state = ctx2[0].playback_state;
      if (dirty & 1)
        playlist_changes.playback_songid = ctx2[0].playback_songid;
      if (dirty & 1)
        playlist_changes.playback_elapsed = ctx2[0].playback_elapsed;
      playlist.$set(playlist_changes);
    },
    i(local) {
      if (current)
        return;
      transition_in(playlist.$$.fragment, local);
      current = true;
    },
    o(local) {
      transition_out(playlist.$$.fragment, local);
      current = false;
    },
    d(detaching) {
      destroy_component(playlist, detaching);
    }
  };
}
function create_fragment5(ctx) {
  let div;
  let nav;
  let a0;
  let t1;
  let span0;
  let t2;
  let a1;
  let t3;
  let a1_class_value;
  let t4;
  let a2;
  let t5;
  let a2_class_value;
  let t6;
  let a3;
  let t7;
  let a3_class_value;
  let a3_title_value;
  let t8;
  let span1;
  let t9;
  let t10;
  let current_block_type_index;
  let if_block1;
  let current;
  let mounted;
  let dispose;
  function select_block_type(ctx2, dirty) {
    if (ctx2[0].connected)
      return create_if_block_3;
    return create_else_block_1;
  }
  let current_block_type = select_block_type(ctx, -1);
  let if_block0 = current_block_type(ctx);
  const if_block_creators = [create_if_block3, create_if_block_13, create_if_block_22];
  const if_blocks = [];
  function select_block_type_2(ctx2, dirty) {
    if (ctx2[1] === "playlist")
      return 0;
    if (ctx2[1] === "files")
      return 1;
    if (ctx2[1] === "artists")
      return 2;
    return -1;
  }
  if (~(current_block_type_index = select_block_type_2(ctx, -1))) {
    if_block1 = if_blocks[current_block_type_index] = if_block_creators[current_block_type_index](ctx);
  }
  return {
    c() {
      div = element("div");
      nav = element("nav");
      a0 = element("a");
      a0.textContent = "Siren!";
      t1 = space();
      span0 = element("span");
      t2 = space();
      a1 = element("a");
      t3 = text(ctx[3]);
      t4 = space();
      a2 = element("a");
      t5 = text("Files");
      t6 = space();
      a3 = element("a");
      t7 = text("Artists");
      t8 = space();
      span1 = element("span");
      t9 = space();
      if_block0.c();
      t10 = space();
      if (if_block1)
        if_block1.c();
      attr(a0, "href", "#playlist");
      attr(a0, "class", "logo");
      attr(a1, "href", "#playlist");
      attr(a1, "class", a1_class_value = "tab " + (ctx[1] === "playlist" ? "current" : "inactive"));
      attr(a1, "title", "Show playlist");
      attr(a2, "href", "#files");
      attr(a2, "class", a2_class_value = "tab " + (ctx[1] === "files" ? "current" : "inactive"));
      attr(a2, "title", "Browse the filesystem");
      attr(a3, "href", "#artists");
      attr(a3, "class", a3_class_value = "tab " + (ctx[1] === "artists" ? "current" : "inactive"));
      attr(a3, "title", a3_title_value = "Browse by " + ctx[0].artistmode);
      attr(div, "class", "mpd");
    },
    m(target, anchor) {
      insert(target, div, anchor);
      append(div, nav);
      append(nav, a0);
      append(nav, t1);
      append(nav, span0);
      append(nav, t2);
      append(nav, a1);
      append(a1, t3);
      append(nav, t4);
      append(nav, a2);
      append(a2, t5);
      append(nav, t6);
      append(nav, a3);
      append(a3, t7);
      append(nav, t8);
      append(nav, span1);
      append(nav, t9);
      if_block0.m(nav, null);
      append(div, t10);
      if (~current_block_type_index) {
        if_blocks[current_block_type_index].m(div, null);
      }
      current = true;
      if (!mounted) {
        dispose = [
          listen(a0, "click", prevent_default(ctx[4])),
          listen(a1, "click", prevent_default(ctx[5])),
          listen(a2, "click", prevent_default(ctx[6])),
          listen(a3, "click", prevent_default(ctx[7]))
        ];
        mounted = true;
      }
    },
    p(ctx2, [dirty]) {
      if (!current || dirty & 8)
        set_data(t3, ctx2[3]);
      if (!current || dirty & 2 && a1_class_value !== (a1_class_value = "tab " + (ctx2[1] === "playlist" ? "current" : "inactive"))) {
        attr(a1, "class", a1_class_value);
      }
      if (!current || dirty & 2 && a2_class_value !== (a2_class_value = "tab " + (ctx2[1] === "files" ? "current" : "inactive"))) {
        attr(a2, "class", a2_class_value);
      }
      if (!current || dirty & 2 && a3_class_value !== (a3_class_value = "tab " + (ctx2[1] === "artists" ? "current" : "inactive"))) {
        attr(a3, "class", a3_class_value);
      }
      if (!current || dirty & 1 && a3_title_value !== (a3_title_value = "Browse by " + ctx2[0].artistmode)) {
        attr(a3, "title", a3_title_value);
      }
      if (current_block_type === (current_block_type = select_block_type(ctx2, dirty)) && if_block0) {
        if_block0.p(ctx2, dirty);
      } else {
        if_block0.d(1);
        if_block0 = current_block_type(ctx2);
        if (if_block0) {
          if_block0.c();
          if_block0.m(nav, null);
        }
      }
      let previous_block_index = current_block_type_index;
      current_block_type_index = select_block_type_2(ctx2, dirty);
      if (current_block_type_index === previous_block_index) {
        if (~current_block_type_index) {
          if_blocks[current_block_type_index].p(ctx2, dirty);
        }
      } else {
        if (if_block1) {
          group_outros();
          transition_out(if_blocks[previous_block_index], 1, 1, () => {
            if_blocks[previous_block_index] = null;
          });
          check_outros();
        }
        if (~current_block_type_index) {
          if_block1 = if_blocks[current_block_type_index];
          if (!if_block1) {
            if_block1 = if_blocks[current_block_type_index] = if_block_creators[current_block_type_index](ctx2);
            if_block1.c();
          } else {
            if_block1.p(ctx2, dirty);
          }
          transition_in(if_block1, 1);
          if_block1.m(div, null);
        } else {
          if_block1 = null;
        }
      }
    },
    i(local) {
      if (current)
        return;
      transition_in(if_block1);
      current = true;
    },
    o(local) {
      transition_out(if_block1);
      current = false;
    },
    d(detaching) {
      if (detaching)
        detach(div);
      if_block0.d();
      if (~current_block_type_index) {
        if_blocks[current_block_type_index].d();
      }
      mounted = false;
      run_all(dispose);
    }
  };
}
var click_handler_4 = () => {
};
function instance5($$self, $$props, $$invalidate) {
  let playlistHeader;
  let view = "playlist";
  let timer = void 0;
  function stopTimer() {
    if (timer !== void 0) {
      window.clearInterval(timer);
      timer = void 0;
    }
  }
  function addArtistPane(pane, after) {
    mpd.artistPanes.forEach((item, i) => {
      if (item.id === after) {
        mpd.artistPanes.splice(i + 1);
      }
    });
    mpd.artistPanes.push(pane);
    $$invalidate(0, mpd);
    pane.sync(conn);
  }
  function addFilePane(pane, after) {
    mpd.filePanes.forEach((item, i) => {
      if (item.id === after) {
        mpd.filePanes.splice(i + 1);
      }
    });
    mpd.filePanes.push(pane);
    $$invalidate(0, mpd);
    pane.sync(conn);
  }
  afterUpdate(() => {
    var elem = document.getElementsByClassName("mc");
    if (elem.length > 0) {
      elem[0].scrollLeft = elem[0].scrollLeftMax;
    }
  });
  let mpd = {
    connected: false,
    mpdconnected: false,
    mpdhost: "",
    artistmode: "",
    playlist: [],
    filePanes: [new PaneFiles(addFilePane, "/")],
    artistPanes: [new PaneArtists(addArtistPane)],
    playback_songid: 0,
    playback_state: "stop",
    playback_elapsed: 0,
    apply: (id, cb) => {
      for (const a of mpd.filePanes) {
        if (a.id === id) {
          cb(a);
          $$invalidate(0, mpd.foo = 1, mpd);
        }
      }
      for (const a of mpd.artistPanes) {
        if (a.id === id) {
          cb(a);
          $$invalidate(0, mpd.foo = 1, mpd);
        }
      }
    }
  };
  var wsURL = (window.location.protocol === "https:" ? "wss://" : "ws://") + window.location.host + window.location.pathname + "mpd/ws";
  let conn = new conn_default(wsURL);
  conn.setConnected = (c) => {
    $$invalidate(0, mpd.connected = c, mpd);
    mpd.filePanes[0].sync(conn);
    mpd.artistPanes[0].sync(conn);
  };
  conn.setMPDConnected = (c) => $$invalidate(0, mpd.mpdconnected = c, mpd);
  conn.setPlaylist = (c) => $$invalidate(0, mpd.playlist = c, mpd);
  conn.setPlaybackStatus = (songid, state, duration2, elapsed) => {
    $$invalidate(0, mpd.playback_songid = songid, mpd);
    $$invalidate(0, mpd.playback_state = state, mpd);
    $$invalidate(0, mpd.playback_elapsed = elapsed, mpd);
    stopTimer();
    if (state === "play") {
      timer = window.setInterval(() => {
        $$invalidate(0, mpd.playback_elapsed += 1, mpd);
      }, 1e3);
    }
  };
  conn.setConfig = (mpdhost, artistmode) => {
    $$invalidate(0, mpd.mpdhost = mpdhost, mpd);
    $$invalidate(0, mpd.artistmode = artistmode, mpd);
  };
  conn.setList = (id, elems) => {
    mpd.apply(id, (pane) => {
      pane.setItems(elems);
    });
  };
  conn.setInodes = (id, ls) => {
    mpd.apply(id, (pane) => {
      pane.setInodes(ls);
    });
  };
  conn.setTrack = (id, track) => {
    mpd.apply(id, (pane) => {
      pane.setTrack(track);
    });
  };
  conn.connect();
  const click_handler = () => $$invalidate(1, view = "playlist");
  const click_handler_1 = () => $$invalidate(1, view = "playlist");
  const click_handler_2 = () => $$invalidate(1, view = "files");
  const click_handler_3 = () => $$invalidate(1, view = "artists");
  const click_handler_5 = () => conn.connect();
  $$self.$$.update = () => {
    if ($$self.$$.dirty & 1) {
      $:
        $$invalidate(3, playlistHeader = "Playlist (" + mpd.playlist.length + ")");
    }
  };
  return [
    mpd,
    view,
    conn,
    playlistHeader,
    click_handler,
    click_handler_1,
    click_handler_2,
    click_handler_3,
    click_handler_5
  ];
}
var App = class extends SvelteComponent {
  constructor(options) {
    super();
    init(this, options, instance5, create_fragment5, safe_not_equal, {});
  }
};
var app_default = App;

// siren.js
new app_default({
  target: document.body
});
//# sourceMappingURL=siren.js.map
