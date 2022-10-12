import {useState} from "react";
import Fulldetails from "./FullDetails";
import "../details.css";
import {useContractKit} from "@celo-tools/use-contractkit";
import {lendmoney, repayloan, closeborrowrequest,ceasenft} from "../utils/loaner";
import { ethers } from "ethers";



const Details = (props) => {
    const { address, performActions } = useContractKit();

    const [loading, setLoading] = useState(false);
    const [showFull, setShowFull]= useState(false)
    const [modalData, setModalData] = useState(null);
    let loanContract = props.loanContract;

    let loans = props.loans;

    if(!loans){
        return(
            <h1>Fetching loans...</h1>
        );
    }
    const modalHandler = (detail) => {
        setShowFull(true)
        setModalData(detail)
    }

    const lendMoney = async (key, loanAmount) => {
        try {
            
            setLoading(true)
            await lendmoney(loanContract, performActions, key, loanAmount);
            await props.getLoans();
        } catch (e) {
            console.log({e})
        } finally {
            setLoading(false)
        }
    };
    const repayLoan = async (key, loanAmount) => {
        try {
            setLoading(true)
            await repayloan(loanContract, performActions, key, loanAmount);
            await props.getLoans();
        } catch (e) {
            console.log({e})
        } finally {
            setLoading(false)
        }
    };

    const closeBorrowRequest = async (key) => {
        try {
            
            setLoading(true)
            await closeborrowrequest(loanContract, performActions, key);
            await props.getLoans();
        } catch (e) {
            console.log({e})
        } finally {
            setLoading(false)
        }
    };

    const ceaseNft = async (key) => {
        try {
            setLoading(true)
            await ceasenft(loanContract, performActions, key);
            await props.getLoans();
        } catch (e) {
            console.log({e})
        } finally {
            setLoading(false)
        }
    };


    return(
        <div className='Details' >
            {loans.map(  (detail, key) => {
                let isBorrowerSame = detail.borrowerAddress.toLowerCase() == address.toLowerCase();
                let isLenderSame = detail.lenderAddress.toLowerCase() == address.toLowerCase();
                let loanStatus;
                if(detail.status == 0){
                    loanStatus = "for loan✔️"                   
                }else if(detail.status == 1){
                    loanStatus = "loaned💰"
                }else{
                    loanStatus = "closed❌"
                }

                let _loanDurationEndDate = new Date(detail.loanDurationEndTimestamp * 1000 );
                let loanDurationEndDate = _loanDurationEndDate.toLocaleDateString().substring(0,4);
                let  amount = ethers.utils.formatEther(detail.loanAmount);
                let amountToBeRepayed = ethers.utils.formatEther(detail.amountToBeRepayed);

                return(
                    <div className="detail" key={key}>
                        <h3>Status: {loanStatus}</h3>
                        <p>Amount: {amount} celo</p>
                        <p>interest: {detail.interest}%</p>
                        <p>nftId: {detail.nftId}</p>
                        <p>nftAddress: {detail.nftAddress.substring(0,5)}</p>
                        <p>Amount after Interest: {amountToBeRepayed} </p>
                        {detail.status == 0 && (
                            <div>
                                <p>loanDuration: {detail.loanDuration} mins </p>
                            </div>
                        )}
                        {detail.status == 1 && (
                            <div>
                                <p>loan Due: {loanDurationEndDate} </p>
                                <p>Loan Duration: {detail.loanDuration} mins </p>
                            </div>
                        )}
                        <p>Borrower Address: {detail.borrowerAddress.substring(0,5)}</p>    
                        <a href={` https://alfajores-blockscout.celo-testnet.org/token/${detail.nftAddress}/instance/${detail.nftId}/`} target="_blank">View on BlockExplorer</a>
                        <button className='newbtn' onClick={() => modalHandler(detail)}>View full Detail</button>  
                        < Fulldetails onClose={() => setShowFull(false)}  detail = {modalData} show = {showFull} />
                        {
                            isBorrowerSame && (
                                <div>
                                    {
                                        detail.status == 0 && (
                                            <div>
                                                <button className='newbtn' onClick = {() => closeBorrowRequest(detail.loanIndex)}> Close Request </button>
                                            </div>
                                        )
                                    }

                                    {
                                        detail.status == 1 && (
                                            <div>
                                                <button className='newbtn' onClick = {() => repayLoan(detail.loanIndex, amountToBeRepayed)}> repay Loan</button>
                                            </div>
                                        )    
                                    }
                                </div>
                            )
                        }

                        {
                            !isBorrowerSame &&(
                                <div>
                                {
                                    detail.status ==0 && (
                                        <div>
                                            <button className='newbtn' onClick={() => lendMoney(detail.loanIndex, amount)}>Lend Money</button>
                                        </div>
                                    )
                                }
                                </div>
                            )
                        }

                        {
                            isLenderSame &&(
                                <div>
                                    { detail.status == 1 &&(
                                        <div>
                                            <button className='newbtn'  onClick={() => ceaseNft(detail.loanIndex)} >Cease Nft</button>
                                        </div>
                                    )
                                   }
                                </div>
                            )
                        }
            
                    </div>
                ) 
            })
            }
        </div>        
    )
}

export default Details;