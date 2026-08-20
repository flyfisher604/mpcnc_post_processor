/*
  property-coverage.js -- measure what the six matrices actually vary.

  integration.md 6.2 states three numbers and calls them reproducible. They were not: the
  script that produced them was never committed, and a hand count cannot be re-run after a
  property is added. This is that script.

  The schema is the authority on what exists, so read it from the post rather than from the
  source:

    post.exe --interrogate --noheader --nointeraction <post.cps> > schema.json
    node tools/property-coverage.js schema.json

  Three measures, and 6.2 says what each does and does not mean:

    varied   -- properties at least one case passes a literal for. Every property runs at its
                default on every case; these are the ones whose ALTERNATIVE has been posted.
    enum     -- enum values reached, counting the factory default as reached.
    boolean  -- boolean states reached, of two per property.

  The test hook of 6.5 is excluded: it is part of the instrument that reaches the others, and
  counting it would inflate the denominator with the harness.
*/

var fs = require('fs');
var path = require('path');

var HOOK = 'mapRapidsTestPersonalLicence';
var MATRICES = ['correct-gcode', 'gcode-structure', 'hobbyist', 'personal', 'professional', 'wcs'];

var schemaPath = process.argv[2];
if (!schemaPath) {
  console.error('usage: node tools/property-coverage.js <schema.json>');
  process.exit(2);
}

var props = JSON.parse(fs.readFileSync(schemaPath, 'utf8')).properties;
var source = MATRICES
  .map(function (m) { return fs.readFileSync(path.join(__dirname, m + '-matrix.js'), 'utf8'); })
  .join('\n');

// A case passes a property as `name:S('x')`, `name:N(3)`, `name:B(false)` or, in a few places,
// a bare literal. Anything else -- a name in a comment, a name in prose -- must not count.
function literalsFor(key) {
  var re = new RegExp('\\b' + key + "\\s*:\\s*(?:[SNB]\\(\\s*)?('[^']*'|\"[^\"]*\"|-?[\\d.]+|true|false)", 'g');
  var found = {}, m;
  while ((m = re.exec(source)) != null) {
    found[m[1].replace(/^['"]|['"]$/g, '')] = true;
  }
  return Object.keys(found);
}

var varied = [], notVaried = [];
var enumReached = 0, enumTotal = 0;
var boolReached = 0, boolTotal = 0;
var partialEnums = [], oneWayBooleans = [];

Object.keys(props).forEach(function (key) {
  if (key == HOOK) {
    return;
  }
  var prop = props[key];
  var set = literalsFor(key);
  (set.length ? varied : notVaried).push(key);

  if (prop.type == 'enum') {
    var ids = prop.values.map(function (v) { return String(v.id); });
    var hit = {};
    hit[String(prop.value)] = true;
    set.forEach(function (v) { if (ids.indexOf(v) >= 0) { hit[v] = true; } });
    var n = Object.keys(hit).filter(function (v) { return ids.indexOf(v) >= 0; }).length;
    enumReached += n;
    enumTotal += ids.length;
    if (n < ids.length) {
      partialEnums.push(key + ' ' + n + '/' + ids.length + ' missing '
        + ids.filter(function (v) { return !hit[v]; }).join(', '));
    }
  } else if (prop.type == 'boolean') {
    var states = {};
    states[String(prop.value).toLowerCase()] = true;
    set.forEach(function (v) { states[String(v).toLowerCase()] = true; });
    var s = ['true', 'false'].filter(function (v) { return states[v]; }).length;
    boolReached += s;
    boolTotal += 2;
    if (s < 2) {
      oneWayBooleans.push(key);
    }
  }
});

var targets = varied.length + notVaried.length;
console.log('properties in schema      ' + Object.keys(props).length
  + ' (' + targets + ' coverage targets, ' + HOOK + ' excluded)');
console.log('properties varied         ' + varied.length + '/' + targets);
console.log('enum values reached       ' + enumReached + '/' + enumTotal);
console.log('boolean states reached    ' + boolReached + '/' + boolTotal);
console.log('');
console.log('never varied (' + notVaried.length + '):');
notVaried.sort().forEach(function (k) { console.log('  ' + k); });
if (partialEnums.length) {
  console.log('');
  console.log('enums not fully reached:');
  partialEnums.forEach(function (line) { console.log('  ' + line); });
}
if (oneWayBooleans.length) {
  console.log('');
  console.log('booleans set one way only:');
  oneWayBooleans.forEach(function (k) { console.log('  ' + k); });
}
