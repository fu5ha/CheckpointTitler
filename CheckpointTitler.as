// --- Settings

[Setting name="Enable" category="Main" description="Enable or disable. Also toggle from menu."]
bool Setting_Enable = true;

[Setting name="Title template" category="Main" description="This is what the title will be set to when checkpoint state changes. Use $cp to insert current checkpoint and $maxcp to insert the total checkpoints on the current map."]
string Setting_TitleTemplate = "Playing An RPG Map! Checkpoint $cp/$maxcp";

[Setting name="Set title command" category="Main" description="The command that is used to change your stream title. Default !title is what Nightbot uses."]
string Setting_TitleCommandBase = "!title";

[Setting name="Allow mods to set title template in chat with !checkpointtitle" category="Main" description="When active, mods can use the command !checkpointtitle <title template> to set the title template as above. Could have a small performance impact in high traffic chatrooms."]
bool Setting_ModsChangeTemplate = true;

// --- Structs

class TwitchBaseState {
    int m_queueId = 0;
    bool m_registered = false;
}

class CheckpointState {
    uint m_currentCP = 0;
    uint m_maxCP = 0;
}

// --- Globals

TwitchBaseState g_twitchBaseState = TwitchBaseState();
CheckpointState g_cpState = CheckpointState();
string g_channelName = "";

// --- OP Callbacks

void RenderMenu() {
	if (UI::MenuItem("\\$09f" + Icons::Twitch + "\\$z Twitch Checkpoint Titler", "", Setting_Enable)) {
	    Setting_Enable = !Setting_Enable;
	}
}

void Main() {
    while (!Twitch::ChannelsJoined()) yield();
    // TODO: maybe support more than one channel?
    array<Twitch::ChannelState@> channels = Twitch::GetJoinedChannels();
    g_channelName = channels[0].m_name;

    while (true) {
        if (Setting_Enable) {
            RegisterTwitchBase();

            if (Setting_ModsChangeTemplate) {
                array<Twitch::Message@> newMessages = Twitch::Fetch(g_twitchBaseState.m_queueId);
                for (uint i = 0; i < newMessages.Length; i++) {
                    HandleMessage(newMessages[i]);
                }
            }

            if (CP::get_inGame()) {
                CheckpointState newState = GetCPState();

                if (newState.m_currentCP != g_cpState.m_currentCP || newState.m_maxCP != g_cpState.m_maxCP) {
                    g_cpState = newState;
                    SendTitleMsg();
                }
            }
        }

        yield();
    }
}

void OnDisabled() {
    UnregisterTwitchBase();
}

// --- Implementation

CheckpointState GetCPState() {
    CheckpointState state = CheckpointState();
    state.m_currentCP = CP::get_curCP();
    state.m_maxCP = CP::get_maxCP();
    return state;
}

void HandleMessage(const Twitch::Message@ &in msg) {
    bool isMod = msg.m_tags.Exists("mod") && string(msg.m_tags["mod"]) == "1";
    bool isBroadcaster = msg.m_tags.Exists("badges") && string(msg.m_tags["badges"]).Contains("broadcaster/");
    if (isMod || isBroadcaster) {
        bool isCmd = msg.m_text.StartsWith("!checkpointtitle ");
        if (isCmd) {
            string[]@ parts = msg.m_text.Split("!checkpointtitle ");
            Setting_TitleTemplate = parts[1];
            Twitch::SendMessage(g_channelName, "@" + msg.m_username + ": Updated checkpoint titler plugin template!");
        }
    }
}

void SendTitleMsg() {
    string title = Setting_TitleTemplate;
    title = title.Replace("$cp", Text::Format("%u", g_cpState.m_currentCP));
    title = title.Replace("$maxcp", Text::Format("%u", g_cpState.m_maxCP));
    string msg = Setting_TitleCommandBase + " " + title;
    Twitch::SendMessage(g_channelName, msg);
}

void RegisterTwitchBase() {
    if (!g_twitchBaseState.m_registered) {
        g_twitchBaseState.m_queueId = Twitch::Register(Twitch::MessageType::ChatMessage);
        g_twitchBaseState.m_registered = true;
    }
}

void UnregisterTwitchBase() {
    if (g_twitchBaseState.m_registered) {
        Twitch::Unregister(g_twitchBaseState.m_queueId);
        g_twitchBaseState.m_registered = false;
    }
}