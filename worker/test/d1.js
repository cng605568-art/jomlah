// A stand-in for Cloudflare D1 on top of Node's built-in SQLite, so the server can be tested
// without Cloudflare. Implements only what src/ uses: prepare().bind().first()/all()/run(), batch().
import { readFileSync, readdirSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

class Statement {
  constructor(db, sql, args = []) {
    this.db = db;
    this.sql = sql;
    this.args = args;
  }
  bind(...args) {
    return new Statement(this.db, this.sql, args);
  }
  async first() {
    return this.db.prepare(this.sql).get(...this.args) ?? null;
  }
  async all() {
    return { results: this.db.prepare(this.sql).all(...this.args) };
  }
  async run() {
    const r = this.db.prepare(this.sql).run(...this.args);
    return { meta: { changes: Number(r.changes) } };
  }
}

export function testDb() {
  const db = new DatabaseSync(':memory:');
  db.exec('PRAGMA foreign_keys = ON'); // D1 has foreign keys on
  const dir = new URL('../migrations/', import.meta.url);
  for (const f of readdirSync(dir).filter((n) => n.endsWith('.sql')).sort()) {
    db.exec(readFileSync(new URL(f, dir), 'utf8'));
  }
  return {
    raw: db,
    prepare: (sql) => new Statement(db, sql),
    async batch(statements) {
      db.exec('BEGIN');
      try {
        const out = [];
        for (const s of statements) out.push(await s.run());
        db.exec('COMMIT');
        return out;
      } catch (e) {
        db.exec('ROLLBACK');
        throw e;
      }
    },
  };
}
