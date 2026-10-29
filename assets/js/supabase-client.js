(function () {
  const config = window.BOUNDARY_SUPABASE_CONFIG || {};
  const ready = Boolean(config.url && config.anonKey && window.supabase?.createClient);
  const client = ready ? window.supabase.createClient(config.url, config.anonKey) : null;

  function fail(error) {
    if (error) throw error;
  }

  function mapTeam(row, players = []) {
    return {
      id: row.id,
      name: row.team_name,
      slug: row.slug,
      captain: row.captain_name,
      mobile: row.captain_mobile || '',
      location: row.location || '',
      description: row.description || '',
      status: row.registration_status,
      reason: row.rejection_reason || '',
      createdAt: row.created_at,
      playerCount: Number(row.player_count || players.length),
      players: players.map((player) => ({
        id: player.id,
        name: player.player_name,
        gotra: player.gotra,
        father: player.father_name,
        mobile: player.mobile_number || '',
        role: player.playing_role || '',
        active: player.is_active,
      })),
      captainUserId: row.captain_user_id,
    };
  }

  async function load() {
    if (!ready) return { configured: false };
    const [{ data: sessionData, error: sessionError }, { data: settingRows, error: settingError }] =
      await Promise.all([
        client.auth.getSession(),
        client.from('tournament_settings').select('*').order('updated_at', { ascending: false }).limit(1),
      ]);
    fail(sessionError);
    fail(settingError);
    const user = sessionData.session?.user || null;
    const settingsRow = settingRows?.[0] || {};
    let teamRows;
    let playerRows;
    if (user) {
      const [teamsResult, playersResult, profileResult] = await Promise.all([
        client.from('teams').select('*').order('created_at'),
        client.from('players').select('*').order('created_at'),
        client.from('profiles').select('role').eq('id', user.id).maybeSingle(),
      ]);
      fail(teamsResult.error);
      fail(playersResult.error);
      fail(profileResult.error);
      teamRows = teamsResult.data || [];
      playerRows = playersResult.data || [];
      const own = teamRows.find((team) => team.captain_user_id === user.id);
      return {
        configured: true,
        client,
        user,
        role: profileResult.data?.role || 'captain',
        settingsRow,
        teamRows,
        playerRows,
        ownTeamId: own?.id || null,
      };
    }
    const [teamsResult, playersResult] = await Promise.all([
      client.from('public_teams').select('*').order('created_at'),
      client.from('public_players').select('*'),
    ]);
    fail(teamsResult.error);
    fail(playersResult.error);
    teamRows = teamsResult.data || [];
    playerRows = (playersResult.data || []).map((player) => ({
      id: player.id,
      player_name: player.player_name,
      gotra: player.gotra,
      father_name: player.father_name,
      playing_role: player.playing_role,
      is_active: true,
      team_id: teamRows.find((team) => team.slug === player.slug)?.id,
    }));
    return { configured: true, client, user: null, role: null, settingsRow, teamRows, playerRows };
  }

  function toAppState(data) {
    const playersByTeam = new Map();
    for (const player of data.playerRows) {
      if (!playersByTeam.has(player.team_id)) playersByTeam.set(player.team_id, []);
      playersByTeam.get(player.team_id).push(player);
    }
    const own = data.teamRows.find((team) => team.id === data.ownTeamId);
    return {
      settings: {
        id: data.settingsRow.id,
        name: data.settingsRow.tournament_name || 'Boundary Premier League',
        description: data.settingsRow.tournament_description || '',
        registrationOpen: data.settingsRow.registration_open ?? true,
        deadline: data.settingsRow.registration_deadline?.slice(0, 10) || '',
        maxPlayers: data.settingsRow.max_players_per_team || 15,
        location: data.settingsRow.location || '',
        contact: data.settingsRow.organizer_contact || '',
        rules: data.settingsRow.rules || '',
      },
      teams: data.teamRows.map((team) => mapTeam(team, playersByTeam.get(team.id) || [])),
      users: [],
      currentUser: data.user
        ? { role: data.role, teamId: own?.id || null, userId: data.user.id }
        : null,
      configured: true,
    };
  }

  window.BoundaryBackend = {
    ready,
    client,
    load: async () => {
      const data = await load();
      return data.configured ? toAppState(data) : data;
    },
    signUp: async ({ phone, password, captain }) => {
      const { data, error } = await client.auth.signUp({
        phone,
        password,
        options: { data: { full_name: captain, mobile_number: phone } },
      });
      fail(error);
      return data;
    },
    verifyPhone: async ({ phone, token }) => {
      const { data, error } = await client.auth.verifyOtp({ phone, token, type: 'sms' });
      fail(error);
      return data;
    },
    signIn: async ({ phone, password }) => {
      const { error } = await client.auth.signInWithPassword({ phone, password });
      fail(error);
    },
    signOut: async () => {
      const { error } = await client.auth.signOut();
      fail(error);
    },
    createTeam: async (team) => {
      const { error } = await client.from('teams').insert(team);
      fail(error);
    },
    savePlayer: async (teamId, playerId, player) => {
      let query = client.from('players');
      query = playerId
        ? query.update(player).eq('id', playerId).eq('team_id', teamId)
        : query.insert({ ...player, team_id: teamId });
      const { error } = await query;
      fail(error);
    },
    removePlayer: async (teamId, playerId) => {
      const { error } = await client.from('players').update({ is_active: false }).eq('id', playerId).eq('team_id', teamId);
      fail(error);
    },
    setTeamStatus: async (teamId, status, reason = null) => {
      const { error } = await client.from('teams').update({ registration_status: status, rejection_reason: reason }).eq('id', teamId);
      fail(error);
    },
    saveSettings: async (settings) => {
      const { error } = await client.from('tournament_settings').update(settings).eq('id', settings.id);
      fail(error);
    },
  };
})();
