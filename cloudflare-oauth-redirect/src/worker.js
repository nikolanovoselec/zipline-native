export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // Get OAuth parameters from query string
    const code = url.searchParams.get('code');
    const state = url.searchParams.get('state');
    
    // If we have code and state, exchange them for a session
    if (code && state) {
      try {
        console.log('Received OAuth callback with code and state');
        
        // Step 1: Exchange the authorization code with Zipline
        // Get Zipline URL from environment variable (configured in wrangler.toml)
        const ziplineUrl = env.ZIPLINE_URL || 'https://your-zipline-instance.com';
        const tokenUrl = new URL(`${ziplineUrl}/api/auth/oauth/oidc`);
        tokenUrl.searchParams.set('code', code);
        tokenUrl.searchParams.set('state', state);
        
        console.log('Exchanging code with Zipline:', tokenUrl.toString());
        
        // Make the request to Zipline to exchange the code
        const exchangeResponse = await fetch(tokenUrl.toString(), {
          method: 'GET',
          redirect: 'manual', // Don't follow redirects automatically
          headers: {
            'User-Agent': 'Zipline-OAuth-Worker/1.0',
          }
        });
        
        console.log('Exchange response status:', exchangeResponse.status);
        const loggedHeaders = Object.fromEntries(exchangeResponse.headers.entries());
        if (loggedHeaders['set-cookie']) {
          loggedHeaders['set-cookie'] = '[redacted for security]';
        }
        console.log('Exchange response headers:', loggedHeaders);
        
        // Extract session cookie from response
        let sessionCookie = null;
        const setCookieHeader = exchangeResponse.headers.get('set-cookie');
        
        if (setCookieHeader) {
          console.log('Set-Cookie header present on exchange response');
          
          // Parse for zipline_session cookie
          const sessionMatch = setCookieHeader.match(/zipline_session=([^;]+)/);
          if (sessionMatch) {
            sessionCookie = sessionMatch[1];
            console.log('Session cookie extracted (length):', sessionCookie.length);
          } else {
            console.log('No zipline_session found in Set-Cookie header');
          }
        } else {
          console.log('No Set-Cookie header in response');
        }
        
        // Check if authentication was successful
        if (exchangeResponse.status === 302 || exchangeResponse.status === 200) {
          if (sessionCookie) {
            // Success! Pass the session cookie to the app
            return redirectToApp(true, sessionCookie, null);
          } else {
            // Success status but no session cookie - this is our current problem
            console.error('Authentication succeeded but no session cookie received');
            return redirectToApp(false, null, 'No session cookie received from server');
          }
        } else if (exchangeResponse.status === 400 || exchangeResponse.status === 401) {
          // Authentication failed
          const errorBody = await exchangeResponse.text();
          console.error('Authentication failed:', errorBody);
          return redirectToApp(false, null, 'Authentication failed: ' + errorBody);
        } else {
          // Unexpected response
          console.error('Unexpected response status:', exchangeResponse.status);
          return redirectToApp(false, null, 'Unexpected response from server');
        }
        
      } catch (error) {
        console.error('Error during OAuth exchange:', error);
        return redirectToApp(false, null, error.message);
      }
    }
    
    // If no code/state, show error
    return redirectToApp(false, null, 'Missing OAuth parameters');
  },
};

// Helper function to generate the redirect HTML
export function redirectToApp(success, sessionCookie, error) {
  const encodedSession = sessionCookie ? btoa(sessionCookie) : null;
  const html = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${success ? 'Login Successful' : 'Login Failed'}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0D1B2A;
            color: #E0F2FF;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            padding: 20px;
            text-align: center;
        }
        .container {
            background: rgba(30, 58, 95, 0.15);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border: 1px solid rgba(224, 242, 255, 0.08);
            border-radius: 20px;
            padding: 40px;
            max-width: 400px;
            width: 100%;
        }
        h1 {
            margin: 0 0 20px 0;
            font-size: 24px;
            font-weight: 600;
        }
        .spinner {
            margin: 20px auto;
            width: 50px;
            height: 50px;
            border: 3px solid rgba(224, 242, 255, 0.1);
            border-top: 3px solid #4A9EFF;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .message {
            color: rgba(224, 242, 255, 0.6);
            font-size: 14px;
            margin-top: 20px;
        }
        .success {
            color: #4AFF74;
        }
        .error {
            background: rgba(255, 74, 74, 0.15);
            border: 1px solid rgba(255, 74, 74, 0.3);
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
            color: #FF4A4A;
        }
        .fallback-button {
            margin-top: 20px;
            padding: 12px 24px;
            background: #4A9EFF;
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
        }
        .fallback-button:hover {
            background: #357ABD;
        }
    </style>
</head>
<body>
    <div class="container">
        ${success ? `
            <h1 class="success">✓ Login Successful!</h1>
            <div class="spinner"></div>
            <p class="message">Redirecting to Zipline app...</p>
            <a href="#" id="fallback" class="fallback-button" style="display: none;">Open Zipline App</a>
        ` : `
            <h1>Login Failed</h1>
            <div class="error">
                <p>${error || 'An error occurred during authentication.'}</p>
                <p>Please try logging in again.</p>
            </div>
        `}
    </div>

    ${success && sessionCookie ? `
    <script>
        // Pass the session cookie to the app
        const encodedSession = ${JSON.stringify(encodedSession)};
        const sessionCookie = encodedSession ? atob(encodedSession) : null;

        // Build callback URL with session
        const callbackUrl = 'zipline://oauth-callback?success=true&session=' + encodeURIComponent(sessionCookie);
        
        // Try to open the app
        try {
            window.location.replace(callbackUrl);
        } catch (e) {
            console.error('location.replace failed:', e);
            window.location.href = callbackUrl;
        }
        
        // Show fallback button after delay
        setTimeout(() => {
            const fallbackBtn = document.getElementById('fallback');
            if (fallbackBtn) {
                // Use intent URL for Android
                const intentUrl = 'intent://oauth-callback?success=true&session=' + encodeURIComponent(sessionCookie) + 
                                 '#Intent;package=com.example.zipline_native_app;scheme=zipline;end';
                fallbackBtn.href = intentUrl;
                fallbackBtn.style.display = 'inline-block';
                document.querySelector('.message').textContent = 'If the app didn\\'t open, click the button below:';
            }
        }, 2000);
        
        // Try intent URL as fallback after longer delay
        setTimeout(() => {
            const intentUrl = 'intent://oauth-callback?success=true&session=' + encodeURIComponent(sessionCookie) + 
                             '#Intent;package=com.example.zipline_native_app;scheme=zipline;end';
            window.location.href = intentUrl;
        }, 3000);
    </script>
    ` : success ? `
    <script>
        // No session cookie received, redirect with error
        const callbackUrl = 'zipline://oauth-callback?success=false&error=' + encodeURIComponent('No session cookie received');
        window.location.replace(callbackUrl);
    </script>
    ` : `
    <script>
        // Authentication failed, redirect with error
        const callbackUrl = 'zipline://oauth-callback?success=false&error=' + encodeURIComponent(${JSON.stringify(error || 'Authentication failed')});
        
        setTimeout(() => {
            window.location.replace(callbackUrl);
        }, 3000);
    </script>
    `}
</body>
</html>`;
  
  return new Response(html, {
    headers: {
      'Content-Type': 'text/html;charset=UTF-8',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  });
}

