const supabase = require('../config/supabase');

const PREFIX = 'ANCC-EMP-';

/**
 * Generates the next sequential employee ID in format ANCC-EMP-(number), e.g. ANCC-EMP-001.
 */
async function fetchNextEmployeeId() {
  try {
    const { data: rows, error } = await supabase
      .from('employees')
      .select('employee_id');

    if (error || !rows) {
      return `${PREFIX}001`;
    }

    let maxSeq = 0;
    const regExp = /ANCC-EMP-(\d+)/i;

    for (const row of rows) {
      const empId = (row.employee_id || '').toString().trim();
      if (!empId) continue;

      const match = empId.match(regExp);
      if (match && match[1]) {
        const seq = parseInt(match[1], 10);
        if (!isNaN(seq) && seq > maxSeq) {
          maxSeq = seq;
        }
      } else {
        const anyNumMatch = empId.match(/(\d+)/);
        if (anyNumMatch && anyNumMatch[1]) {
          const val = parseInt(anyNumMatch[1], 10);
          if (!isNaN(val) && val > maxSeq && val < 100000) {
            maxSeq = val;
          }
        }
      }
    }

    const nextSeq = maxSeq + 1;
    return `${PREFIX}${String(nextSeq).padStart(3, '0')}`;
  } catch (err) {
    console.error('Error generating next employee id:', err);
    return `${PREFIX}001`;
  }
}

module.exports = {
  fetchNextEmployeeId,
  PREFIX,
};
