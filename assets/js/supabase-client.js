(function () {
  const config = window.BOUNDARY_SUPABASE_CONFIG || {};
  const client = config.url && config.anonKey && window.supabase?.createClient
    ? window.supabase.createClient(config.url, config.anonKey)
    : null;

  function assertReady() {
    if (!client) throw new Error('Supabase is not configured. Check assets/js/supabase-config.js.');
  }

  function unwrap(result) {
    if (result.error) throw result.error;
    return result.data;
  }

  const mapPlayer = (row) => ({
    id: row.id,
    team_id: row.team_id,
    name: row.player_name,
    gotra: row.gotra,
    father: row.father_name,
    mobile: row.mobile_number || '',
    role: row.playing_role || '',
    active: row.is_active,
  });

  const mapTeam = (row, players = []) => ({
    id: row.id,
    name: row.team_name,
    slug: row.slug,
    captain: row.captain_name,
    mobile: row.captain_mobile || '',
    location: row.location || '',
    status: row.registration_status,
    reason: row.rejection_reason || '',
    createdAt: row.created_at,
    players,
    captainUserId: row.captain_user_id,
  });

  async function load() {
    assertReady();
    const session = unwrap(await client.auth.getSession()).session;
    const user = session?.user || null;
    const settingsRows = unwrap(await client.from('tournament_settings').select('*').order('updated_at', { ascending: false }).limit(1));
    const [teamResult, playerResult] = await Promise.all([
      client.from('public_teams').select('*').order('created_at'),
      client.from('public_players').select('*'),
    ]);
    const publicTeamRows = unwrap(teamResult);
    const publicPlayerRows = unwrap(playerResult);
    let role = null;
    let teams = publicTeamRows.map((row) => mapTeam(row, publicPlayerRows.filter((player) => player.slug === row.slug).map((player) => ({
      id: player.id, name: player.player_name, gotra: player.gotra, father: player.father_name,
      role: player.playing_role || '', active: true,
    }))));

    if (user) {
      role = unwrap(await client.from('profiles').select('role').eq('id', user.id).maybeSingle())?.role || 'captain';
      if (role === 'admin') {
        const [teamRowsResult, playerRowsResult] = await Promise.all([
          client.from('teams').select('*').order('created_at'),
          client.from('players').select('*').order('created_at'),
        ]);
        const playerRows = unwrap(playerRowsResult).map(mapPlayer);
        teams = unwrap(teamRowsResult).map((row) => mapTeam(row, playerRows.filter((player) => player.team_id === row.id)));
      } else {
        const ownTeamRow = unwrap(await client.from('teams').select('*').eq('captain_user_id', user.id).maybeSingle());
        if (ownTeamRow) {
          const ownPlayers = unwrap(await client.from('players').select('*').eq('team_id', ownTeamRow.id).order('created_at')).map(mapPlayer);
          const ownTeam = mapTeam(ownTeamRow, ownPlayers);
          const existing = teams.findIndex((team) => team.id === ownTeam.id);
          if (existing >= 0) teams[existing] = ownTeam;
          else teams.push(ownTeam);
        }
      }
    }

    const settings = settingsRows?.[0] || {};
    return {
      settings: {
        id: settings.id,
        name: settings.tournament_name || 'Boundary Premier League',
        description: settings.tournament_description || '',
        registrationOpen: settings.registration_open ?? true,
        deadline: settings.registration_deadline?.slice(0, 10) || '',
        maxPlayers: settings.max_players_per_team || 15,
        location: settings.location || '',
        contact: settings.organizer_contact || '',
        rules: settings.rules || '',
      },
      teams,
      currentUser: user ? { userId: user.id, email: user.email, role } : null,
      configured: true,
    };
  }

  async function signUp({ email, password, captain, mobile }) {
    assertReady();
    return unwrap(await client.auth.signUp({ email, password, options: { data: { full_name: captain, mobile_number: mobile } } }));
  }

  async function signIn({ email, password }) {
    assertReady();
    return unwrap(await client.auth.signInWithPassword({ email, password }));
  }

  async function signOut() {
    assertReady();
    unwrap(await client.auth.signOut());
  }

  async function createTeam(team) {
    assertReady();
    const { user } = unwrap(await client.auth.getUser());
    if (!user) throw new Error('Your session expired. Please sign in again.');
    unwrap(await client.from('teams').insert({
      team_name: team.name,
      slug: team.slug,
      captain_user_id: user.id,
      captain_name: team.captain,
      captain_mobile: team.mobile,
      location: team.location || null,
      registration_status: 'pending',
    }));
  }

  async function savePlayer(teamId, playerId, player) {
    assertReady();
    const row = {
      player_name: player.name,
      gotra: player.gotra,
      father_name: player.father,
      mobile_number: player.mobile,
      playing_role: player.role || null,
      is_active: true,
    };
    const result = playerId
      ? client.from('players').update(row).eq('id', playerId).eq('team_id', teamId)
      : client.from('players').insert({ ...row, team_id: teamId });
    unwrap(await result);
  }

  async function removePlayer(teamId, playerId) {
    assertReady();
    unwrap(await client.from('players').update({ is_active: false }).eq('id', playerId).eq('team_id', teamId));
  }

  async function setTeamStatus(teamId, status, reason = null) {
    assertReady();
    unwrap(await client.from('teams').update({ registration_status: status, rejection_reason: reason }).eq('id', teamId));
  }

  async function saveSettings(settings) {
    assertReady();
    unwrap(await client.from('tournament_settings').update({
      tournament_name: settings.name,
      tournament_description: settings.description,
      max_players_per_team: settings.maxPlayers,
      registration_deadline: settings.deadline || null,
      organizer_contact: settings.contact || null,
      registration_open: settings.registrationOpen,
    }).eq('id', settings.id));
  }

  window.BoundaryBackend = {
    ready: Boolean(client), client, load, signUp, signIn, signOut,
    createTeam, savePlayer, removePlayer, setTeamStatus, saveSettings,
  };
})();
