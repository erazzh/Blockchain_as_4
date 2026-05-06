async function connect() {
    if (window.ethereum) {
        await window.ethereum.request({ method: 'eth_requestAccounts' });
        alert("Connected!");
    } else {
        alert("Please install MetaMask");
    }
}

document.getElementById('connectBtn').onclick = connect;

function vote(type) {
    // В реальности здесь вызывается функция контракта castVote
    console.log("Voting type:", type);
    alert("Vote submitted: " + (type === 1 ? "FOR" : "AGAINST"));
}