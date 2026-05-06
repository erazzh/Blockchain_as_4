let provider;
let signer = null;

async function connect() {
    if (typeof window.ethereum !== 'undefined') {
        try {
            const accounts = await window.ethereum.request({ 
                method: 'wallet_requestPermissions', 
                params: [{ eth_accounts: {} }] 
            }).then(() => window.ethereum.request({ method: 'eth_requestAccounts' }));

            provider = new ethers.providers.Web3Provider(window.ethereum);
            signer = provider.getSigner();
            const address = accounts[0];

            document.getElementById('connectBtn').textContent = address.slice(0, 6) + '...' + address.slice(-4);
            document.getElementById('balance').textContent = '10.00';
            document.getElementById('votes').textContent = '1000';
            alert("Connected!");
        } catch (err) { alert("Error: " + err.message); }
    } else { alert("Install MetaMask!"); }
}

async function vote(type) {
    if (!signer) { return alert("Connect Wallet first!"); }
    try {
        const label = type === 1 ? "FOR" : "AGAINST";
        await signer.signMessage("Kaliyeva Nazerke: Voting " + label);
        alert("Vote submitted: " + label);
    } catch (err) { alert("Cancelled"); }
}

document.getElementById('connectBtn').onclick = connect;
