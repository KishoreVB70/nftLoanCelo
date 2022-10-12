import React from "react";
import { Container, Nav } from "react-bootstrap";
import { useContractKit } from "@celo-tools/use-contractkit";
import { Notification } from "./components/ui/Notifications";
import Wallet from "./components/Wallet";
import Cover from "./components/Cover";
import Input from "./components/Input";
import { useBalance} from "./hooks";
import { useState, useEffect} from "react";

import { getloanid, getloans } from "./utils/loaner";
import abi from "./contracts/abi.json";

import "./App.css";
import Details from "./components/Details";

const App = function AppWrapper() {
  let loanContractAddress = "0xf00daadFA45EaaA978Ff736cD800559AfF1fb934"; 
  const [showModal, setShowModal] = useState();
  const [loans, setLoans] = useState();
  const [loanContract, setLoanContract] = useState();
  const { getConnectedKit, address, destroy, connect } = useContractKit();
  const { balance } = useBalance();

  const getLoans = async() => {
    const kit = await getConnectedKit();
    let _loanContract = new kit.web3.eth.Contract(abi.abi, loanContractAddress);
    setLoanContract(_loanContract);
    let loanId = await getloanid(_loanContract);
    let loansUh = await getloans(_loanContract, loanId);
    setLoans(loansUh);
    
  }

  useEffect(() => {
    getLoans();
  },[] );

  return (
    <>
      <Notification />
      {address ? (
        <Container fluid="md">
          <Nav className="justify-content-end pt-3 pb-5">
            <Nav.Item>
              {/*display user wallet*/}
              <Wallet
                address={address}
                amount={balance.CELO}
                symbol="CELO"
                destroy={destroy}
              />
            </Nav.Item>
          </Nav>
          {/* display cover */}
          <main>
            <div>
                  <button className="askForLoan bigBtn" onClick={() => setShowModal(true)} >Ask for Loan</button>
                  <Input onClose={() => setShowModal(false)} loanContractAddress = {loanContractAddress} show={showModal} loanContract={loanContract} getLoans = {getLoans} />
                  <Details  loans= {loans} loanContract={loanContract}  getLoans = {getLoans} />
            </div>
          </main>
        </Container>
      ) : (
        // display cover if user is not connected
        <div className="App">
          <header className="App-header">
            <Cover connect={connect} />
          </header>
        </div>
      )}
    </>
  );
};

export default App;
