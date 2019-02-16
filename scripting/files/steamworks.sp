public void AddServerToTracker()
{
    LogMessage("Adding to tracker");

    int iIp = GetConVarInt(FindConVar("hostip"));
    int iPort = GetConVarInt(FindConVar("hostport"));
    char sHostIp[32];
    char sURLAddress[2048];

    Format(sHostIp, sizeof(sHostIp), "%d.%d.%d.%d", iIp >>> 24 & 255, iIp >>> 16 & 255, iIp >>> 8 & 255, iIp & 255);

    Format(sURLAddress, sizeof(sURLAddress), "https://sm.hexa-core.eu/api/v1/tracker/2/8/%s/%s/%i?pHash=%s&pName=%s&pAuthor=%s", PLUGIN_VERSION, sHostIp, iPort, PLUGIN_HASH, PLUGIN_NAME, PLUGIN_AUTHOR);
    LogMessage(sURLAddress);

    Handle hHTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sURLAddress);
    bool bNetwork = SteamWorks_SetHTTPRequestNetworkActivityTimeout(hHTTPRequest, 10);
    bool bHeader = SteamWorks_SetHTTPRequestHeaderValue(hHTTPRequest, "api_key", API_KEY);
    bool bCallback = SteamWorks_SetHTTPCallbacks(hHTTPRequest, TrackerCallBack);

    if (bNetwork == false || bHeader == false || bCallback == false) {

        delete hHTTPRequest;
        return;
    }

    bool bRequest = SteamWorks_SendHTTPRequest(hHTTPRequest);
    
    if (bRequest == false) {

        delete hHTTPRequest;
        return;
    }

    SteamWorks_PrioritizeHTTPRequest(hHTTPRequest);
}

public int TrackerCallBack(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
    if (bFailure || !bRequestSuccessful) {

        delete hRequest;
        return;
    }
    
    int iBodySize;
    
    if (!SteamWorks_GetHTTPResponseBodySize(hRequest, iBodySize)) {

        delete hRequest;
        return;
    }

    char[] szBody = new char[iBodySize + 1];
    
    if (!SteamWorks_GetHTTPResponseBodyData(hRequest, szBody, iBodySize)) {

        delete hRequest;
        return;
    }

    GetTrackerOutput(szBody);
}

void GetTrackerOutput(const char[] szBody)
{
    KeyValues hKeyValues = new KeyValues("response");
    
    if (hKeyValues.ImportFromString(szBody)) {

        if (hKeyValues.GotoFirstSubKey()) {

            char szHttpCode[64];
            char szMesasge[512];

            hKeyValues.GetString("http_code", szHttpCode, sizeof(szHttpCode));

            if (StrEqual(szHttpCode, "API_PLUGIN_VERSION_OUTDATED", false) || StrEqual(szHttpCode, "API_PLUGIN_OUTDATED", false)) {
                
                hKeyValues.GetString("message", szMesasge, sizeof(szMesasge));
                LogError(szMesasge);

            } else if (StrEqual(szHttpCode, "API_TOO_MANY_REQUESTS", false)) {

                hKeyValues.GetString("message", szMesasge, sizeof(szMesasge));
                LogMessage(szMesasge);
            }
        }
    }

    delete hKeyValues;
}

public void WebLinks_Initialize(int client, char[] sz_Param, char[] sz_Address, int len)
{
    if (IsValidClient(client)) {

        char szClientIp[64];
        //char szBuffer[512];
        char szURLAddress[512];
        char szSteamId[128];
        
        GetClientAuthId(client, AuthId_SteamID64, szSteamId, sizeof(szSteamId));
        GetClientIP(client, szClientIp, sizeof(szClientIp));
        ReplaceTextVariables(client, sz_Address, len);
        
        Format(szURLAddress, sizeof(szURLAddress), "%s/api/v2/request/create", WEBLINKS_API);
       
        Handle hHTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, szURLAddress);

        if (hHTTPRequest == INVALID_HANDLE) {

            LogError("ERROR hRequest(%i): %s", hHTTPRequest, sz_Address);
            return;
	    }

        SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "steamId", szSteamId);
        SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "playerIp", szClientIp);
        SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "url", sz_Address);
        SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "fetchMethod", sFetchMethod);
        SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "customParams", sz_Param);

        bool bNetwork = SteamWorks_SetHTTPRequestNetworkActivityTimeout(hHTTPRequest, 20);
        bool bContext = SteamWorks_SetHTTPRequestContextValue(hHTTPRequest, GetClientUserId(client));
        bool bCallback = SteamWorks_SetHTTPCallbacks(hHTTPRequest, WebLinks_OpenWeb);
        
        if (bNetwork == false || bCallback == false || bContext == false) {
            
            delete hHTTPRequest;
            return;
        }

        bool bRequest = SteamWorks_SendHTTPRequest(hHTTPRequest);

        if (bRequest == false) {

            delete hHTTPRequest;
            return;
        }

        SteamWorks_PrioritizeHTTPRequest(hHTTPRequest);
    }
}

public int WebLinks_OpenWeb(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (IsValidClient(client)) {

        if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {

            PrintToChat(client, "%s Something went wrong > HTTP Code: %s", TAG, eStatusCode);
            
            delete hRequest;
            return;
        }
        
        int iBodySize;

        if (!SteamWorks_GetHTTPResponseBodySize(hRequest, iBodySize)) {
            
            delete hRequest;
            return;
        }

        char[] szBody = new char[iBodySize + 1];
        
        if (!SteamWorks_GetHTTPResponseBodyData(hRequest, szBody, iBodySize)) {
            
            delete hRequest;
            return;
        }

        KeyValues hKeyValues = new KeyValues("response");
        
        if (hKeyValues.ImportFromString(szBody)) {

            if (hKeyValues.GotoFirstSubKey()) {

                char szHttpCode[64];
                
                hKeyValues.GetString("http_code", szHttpCode, sizeof(szHttpCode));
                
                if (StrEqual(szHttpCode, "API_REQUEST_SUCCESS", false)) {

                    if (bCSGO) {

                        PrintToChat(client, "%s %T", TAG, "Chat CSGO Info", client);

                    } else {

                        char szBuffer[2048];
                        char szSteamId[128];

                        GetClientAuthId(client, AuthId_SteamID64, szSteamId, sizeof(szSteamId));
                        Format(szBuffer, sizeof(szBuffer), "%s/method/%s", WEBLINKS_API, szSteamId);
                        ShowMOTDPanel(client, "WebLinks by ESK0 & NOMIS", szBuffer, MOTDPANEL_TYPE_URL);
                    }

                } else {

                    PrintToChat(client, "%s Something went wrong > API Code: %s", TAG, szHttpCode);
                }
            }
        }
    }
}
